package ExecutionProfile;
use parent 'Displayable';

use strict;
use warnings;

use Data::Dumper;
use Scalar::Util qw(refaddr);
use List::Util qw(min max);
use Log::Log4perl qw(get_logger);

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';

use FreeSpace;
use ProcessorRange;
use BinarySearchTree;

use overload '""' => \&stringification;

sub new {
	my $class = shift;
	my $processors_number = shift;
	my $cluster_size = shift;
	my $reduction_algorithm = shift;
	my $starting_time = shift;

	my $self = {
		processors_number => $processors_number,
		cluster_size => $cluster_size,
		reduction_algorithm => $reduction_algorithm
	};

	my $infinity = 0 + "inf";

	#keys = [starting_time, duration, processors_number]
	$self->{profile_tree} = BinarySearchTree->new([-1, -1, -1]);
	$self->{profile_tree}->add_content([(defined($starting_time) ? $starting_time : 0), $infinity, $processors_number],FreeSpace->new(0, $infinity, [0, $self->{processors_number} - 1]));
	bless $self, $class;
	return $self;
}

sub find_place {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $place;

	$self->{profile_tree}->nodes_loop($start_key, $end_key, sub {
		my $node = shift;

		$place = $node;
		return 0;
	});

	return $place;
}

sub find_impacted_place_by_add_task {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $starting_time = shift;
	my $task_processor_range = shift;

	my @impacted_nodes;

	$self->{profile_tree}->nodes_loop($start_key, $end_key, sub {
		my $node = shift;

		#If freespace is on time interval of task
		if (($node->{content}->{starting_time} + $node->{content}->{duration}) >= $starting_time) {
			my $test_range = $node->{content}->{processors}->copy_range();
			$test_range->remove($task_processor_range);

			#If at least a cpu of task are in cpu range of freespace
			if ($test_range->size() < $node->{content}->{processors}->size()) {
				push @impacted_nodes, $node;
			}
			$test_range->free_allocated_memory();
		}
		return 1;
	});

	return @impacted_nodes;
}

sub add_task {
	my $self = shift;
	my $starting_time = shift;
	my $duration = shift;
	my $processors_number = shift;

	my @impacted_nodes;
	my $task_processor_range;

	my $start_key = [$starting_time, $duration, $processors_number];
	my $infinity = 0 + "inf";
	my $end_key = [$infinity, $infinity, $infinity];

	my $node = $self->find_place($start_key, $end_key);

	#Take information of node
	$starting_time = $node->{content}->{starting_time};
	$task_processor_range = $node->{content}->{processors}->copy_range();
	$task_processor_range->reduce_to_basic($processors_number);

	$start_key = [0, 0, 0];
	$end_key = [$starting_time + $duration, $infinity, $infinity];
	@impacted_nodes = $self->find_impacted_place_by_add_task($start_key, $end_key, $starting_time, $task_processor_range);

	my @created_spaces;
	for my $space (@impacted_nodes) {
		$self->{profile_tree}->remove_content($space->{key});
		push @created_spaces, $self->cut_freespace($space, $starting_time, $duration, $task_processor_range);
	}
	$task_processor_range->invert($self->{processors_number});

	my @remaining_useful_spaces;
	for my $space (@created_spaces) {
		push @remaining_useful_spaces, $space if ($self->is_necessary_freespace($space, \@created_spaces));
	}

	$self->{profile_tree}->add_content([$_->{starting_time}, $_->{duration}, $_->{processors}->size()], $_) for @remaining_useful_spaces;

	return FreeSpace->new($starting_time, $duration, $task_processor_range);
}

sub cut_freespace {
	my $self = shift;
	my $node = shift;
	my $task_starting_time = shift;
	my $task_duration = shift;
	my $task_processors = shift;
	my $infinity = 0 + "inf";
	my $freespace = $node->{content};

	my @new_locations;

	if ($freespace->{starting_time} < $task_starting_time) {
		my $left_freespace = FreeSpace->new($freespace->{starting_time}, $task_starting_time-$freespace->{starting_time}, $freespace->{processors});
		push @new_locations, $left_freespace;
	}

	my $new_processors_range = $freespace->{processors}->copy_range();
	$new_processors_range->remove($task_processors);

	if ($new_processors_range->size() > 0) {
		my $new_freespace = FreeSpace->new($freespace->{starting_time}, $freespace->{duration}, $new_processors_range);
		push @new_locations, $new_freespace;
	} else {
		$new_processors_range->free_allocated_memory();
	}

	my $duration = ($freespace->{duration} == $infinity) ? $infinity : $freespace->{duration} - ($freespace->{starting_time} + ($task_starting_time + $task_duration));
	my $right_freespace = FreeSpace->new($task_starting_time+$task_duration, $duration, $freespace->{processors});
	push @new_locations, $right_freespace;

	return @new_locations;
}

sub remove_task {
	my $self = shift;
	my $starting_time = shift;
	my $duration = shift;
	my $cpu_range = shift;
	my @impacted_nodes;
	my @impacted_freespaces;

	my $start_key = [0, 0, 0];
	my $infinity = 0 + "inf";
	my $end_key = [$starting_time + $duration + 1, $infinity, $infinity];

	$self->{profile_tree}->nodes_loop($start_key, $end_key, sub {
		my $node = shift;
		if (($node->{content}->{starting_time} + $node->{content}->{duration}) >= $starting_time) {
			push @impacted_nodes, $node;
			push @impacted_freespaces, $node->{content};
		}
		return 1;
	});

	for my $space (@impacted_nodes) {
		$self->{profile_tree}->remove_content($space->{key});
	}

	my $task_freespace = FreeSpace->new($starting_time, $duration, $cpu_range);
	push @impacted_freespaces, $task_freespace;

	my @created_spaces = $self->extend_freespace(\@impacted_freespaces);

	my @remaining_useful_spaces;
	for my $space (@created_spaces) {
		push @remaining_useful_spaces, $space if ($self->is_necessary_freespace($space, \@created_spaces));
	}

	$self->{profile_tree}->add_content([$_->{starting_time}, $_->{duration}, $_->{processors}->size()], $_) for @remaining_useful_spaces;

	return;
}

sub extend_freespace {
	my $self = shift;
	my $freespaces = shift;

	my $infinity = 0 + "inf";
	my @new_locations;
	my %events;

	for my $space (@{$freespaces}) {
		push @{$events{$space->{starting_time}}{start}}, $space;
		push @{$events{$space->{starting_time} + $space->{duration}}{end}}, $space;
	}

	my @times;
	push @times, $_ for keys %events;
	@times = sort {$a <=> $b} @times;

	my %ranges;
	my @range_list;

	for my $t (@times) {
		my $cpu;
		my $time = $t;

		for my $f (@{$events{$time}{end}}) {
			@range_list = grep { "$_" ne "$f->{processors}" } @range_list;
		}

		for my $f (@{$events{$time}{start}}) {
			push @range_list, $f->{processors};
		}

		for my $r (@range_list) {
			if (!defined $cpu) {
				$cpu = $r->copy_range();
			} else {
				$cpu->add($r);
			}
		}

		if (!%ranges) {
			my $new_range = $cpu->copy_range();
			my $ref = refaddr $new_range;
			if ($time != $infinity) {
				push @{$ranges{$ref}{range}}, $new_range;
				$ranges{$ref}{start} = $time;
			}
		} else {
			for my $r (keys %ranges) {
				if ($ranges{$r}{start} != $infinity)
				{
					if (defined $cpu) {
						my $test_range = $ranges{$r}{range}->[0]->copy_range();
						$test_range->intersection($cpu);

						if ($test_range->size() < $ranges{$r}{range}->[0]->size()) {
							my $new_freespace = FreeSpace->new($ranges{$r}{start}, $time - $ranges{$r}{start} , $ranges{$r}{range}->[0]);
							push @new_locations, $new_freespace;

							my $new_range = $test_range->copy_range();
							my $ref = refaddr $new_range;
							push @{$ranges{$ref}{range}}, $test_range;
							$ranges{$ref}{start} = $ranges{$r}{start};
							delete $ranges{$r};

						} elsif ($test_range->size() < $cpu->size()) {
							my $new_range = $cpu->copy_range();
							my $ref = refaddr $new_range;
							push @{$ranges{$ref}{range}}, $new_range;
							$ranges{$ref}{start} = $time;
						}
					} else {
						my $new_freespace = FreeSpace->new($ranges{$r}{start}, $time - $ranges{$r}{start} , $ranges{$r}{range}->[0]);
						push @new_locations, $new_freespace;
						delete $ranges{$r};
					}
				}
			}
		}
	}

	#Create infinity freespace
	for my $r (keys %ranges) {
		my $new_freespace = FreeSpace->new($ranges{$r}{start}, $infinity , $ranges{$r}{range});
		push @new_locations, $new_freespace;
	}

	return @new_locations;
}

sub is_necessary_freespace {
	my $self = shift;
	my $freespace = shift;
	my $freespaces = shift;

	my $infinity = 0 + "inf";

	for my $space (@{$freespaces}) {
		if (!($space->compare($freespace))) {
			if ($freespace->{starting_time} >= $space->{starting_time}) {
				if (($space->{duration} == $infinity) or ($space->{duration} != $infinity and $freespace->{duration} != $infinity and
					($freespace->{starting_time} + $freespace->{duration} <= $space->{starting_time} + $space->{duration}))) {

					my $test_processors_range = $freespace->{processors}->copy_range();
					$test_processors_range->intersection($space->{processors});

					return 0 if ($test_processors_range->size() == $freespace->{processors}->size());

					$test_processors_range->free_allocated_memory();
				}
			}
		}
	}

	return 1;
}

sub stringification {
	my $self = shift;
	my $infinity = 0 + "inf";
	my @profiles;

	$self->{profile_tree}->nodes_loop([0,0,0], [$infinity, $infinity, $infinity],
		sub {
			my $profile = shift;
			push @profiles, $profile;
			return 1;
		});

	return join(', ', @profiles);
}

sub save_svg {
	my ($self, $svg_filename, $time) = @_;
	$time = 0 unless defined $time;

	my @freespaces;
	my $last_starting_time = 0;
	my $infinity = 0 + "inf";
	$self->{profile_tree}->nodes_loop([0,0,0], [$infinity, $infinity, $infinity],
		sub {
			my $node = shift;
			#test for sentinel
			return 1 if ($node->{key}->[0] == -1);
			my $freespace = $node->{content};
			my $starting_time = $freespace->{starting_time};
			$last_starting_time = $starting_time if $starting_time > $last_starting_time;
			print STDERR "freespace is $freespace\n";
			push @freespaces, $freespace;
			return 1;
		});

	$last_starting_time = ($last_starting_time > 0) ? $last_starting_time + ($last_starting_time * 50)/100 : 10;

	open(my $filehandle, '>', "$svg_filename") or die "unable to open $svg_filename";

	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$last_starting_time;
	my $h_ratio = 600/$self->{processors_number};

	# red line at the current time
	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	$_->svg($filehandle, $w_ratio, $h_ratio, $last_starting_time) for @freespaces;

	print $filehandle "</svg>\n";
	close $filehandle;
	return;
}

1;
