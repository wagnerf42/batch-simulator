package ExecutionProfile2;
use parent 'Displayable';

use strict;
use warnings;

use Data::Dumper;
use List::Util qw(min max);
use Log::Log4perl qw(get_logger);

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';

use FreeSpace;
use ProcessorRange;
use BinarySearchTree2;

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
	$self->{profile_tree} = BinarySearchTree2->new([-1, -1, -1]);
	$self->{profile_tree}->add_content([(defined($starting_time) ? $starting_time : 0), $infinity, $processors_number],FreeSpace->new(0, $infinity, [0, $self->{processors_number} - 1]));
	bless $self, $class;
	return $self;
}

sub add_task {
	my $self = shift;
	my $starting_time = shift;
	my $duration = shift;
	my $processors_number = shift;

	my @impacted_nodes;

	#TODO test undef in node2->nodes_loops
	my $start_key = [0, $duration, $processors_number];
	my $infinity = 0 + "inf";
	my $end_key = [$infinity, $infinity, $infinity];
	$self->{profile_tree}->nodes_loop($start_key, $end_key, sub {
		my $node = shift;
		print STDERR "tu vas fonctionner\n";
		push @impacted_nodes, $node;
		return 1;
	});

	if(@impacted_nodes > 0) {
		#create the processor_range for task with the first node
		my $task_processor_range = $impacted_nodes[0]->{content}->{processors}->copy_range();
		$task_processor_range->reduce_to_basic($processors_number);

		$self->cut_freespace($_, $starting_time, $duration, $task_processor_range) for @impacted_nodes;
		$task_processor_range->free_allocated_memory();
	}
}

sub cut_freespace {
	my $self = shift;
	my $node = shift;
	my $task_starting_time = shift;
	my $task_duration = shift;
	my $task_processors = shift;

	my $infinity = 0 + "inf";
	my $freespace = $node->{content};

	$self->{profile_tree}->remove_content($node->{key});


	if ($freespace->{starting_time} != $task_starting_time) {
		print STDERR "test\n";
		my $left_freespace = FreeSpace->new($freespace->{starting_time}, $task_starting_time-$freespace->{starting_time}, $freespace->{processors});
		$self->{profile_tree}->add_content([$left_freespace->{starting_time}, $left_freespace->{duration}, $left_freespace->{processors}->size()], $left_freespace);
	}

	my $duration = ($freespace->{duration} == $infinity) ? $infinity : $freespace->{duration}-$task_duration;
	my $right_freespace = FreeSpace->new($task_starting_time+$task_duration, $duration, $freespace->{processors});
	$self->{profile_tree}->add_content([$right_freespace->{starting_time}, $right_freespace->{duration}, $right_freespace->{processors}->size() - $task_processors->size()], $right_freespace);

	if ($task_processors->size() <= $freespace->{processors}->size()) {
		my $new_processors_range = $freespace->{processors}->copy_range();
		$new_processors_range->remove($task_processors);
		if ($new_processors_range->size() > 0) {
			my $new_freespace = FreeSpace->new($freespace->{starting_time}, $freespace->{duration}, $new_processors_range);
			$self->{profile_tree}->add_content([$new_freespace->{starting_time}, $new_freespace->{duration}, $new_freespace->{processors}->size()], $new_freespace);
		}
	}

	#free memory of freespace unused
	#$freespace->{processors}->free_allocated_memory();
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
	my $last_ending_time = 0;
	my $infinity = 0 + "inf";
	$self->{profile_tree}->nodes_loop([0,0,0], [$infinity, $infinity, $infinity],
		sub {
			my $node = shift;
			#test for sentinel
			return 1 if ($node->{key}->[0] == -1);
			my $freespace = $node->{content};
			my $ending_time = $freespace->ending_time();
			$last_ending_time = $ending_time if $ending_time != $infinity and $ending_time > $last_ending_time;
			print STDERR "freespace is $freespace\n";
			push @freespaces, $freespace;
			return 1;
		});

	$last_ending_time = 10 unless $last_ending_time ;

	open(my $filehandle, '>', "$svg_filename") or die "unable to open $svg_filename";

	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$last_ending_time;
	my $h_ratio = 600/$self->{processors_number};

	# red line at the current time
	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	$_->svg($filehandle, $w_ratio, $h_ratio, $last_ending_time) for @freespaces;

	print $filehandle "</svg>\n";
	close $filehandle;
	return;
}

1;
