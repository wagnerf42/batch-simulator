#!/usr/bin/env perl
use strict;
use warnings;

use ExecutionProfile;

my $space = ExecutionProfile->new(10);
$space->tycat();
my $task = $space->add_task(0,3,4);
print STDERR "__________________AJOUT tache de durée 3 avec 4 cpu\n";
$space->tycat();
my $task1 = $space->add_task(0,1,3);
print STDERR "__________________AJOUT tache de durée 1 avec 3 cpu\n";
$space->tycat();
my $task2 = $space->add_task(0,4,5);
print STDERR "__________________AJOUT tache de durée 4 avec 5 cpu\n";
$space->tycat();
$space->remove_task($task1->{starting_time},$task1->{duration},$task1->{processors});
print STDERR "__________________SUPPRIME tache de durée $task1->{duration} avec pour range $task1->{processors} qui commence à $task1->{starting_time}\n";
$space->tycat();
$space->remove_task($task2->{starting_time},$task2->{duration},$task2->{processors});
print STDERR "__________________SUPPRIME tache de durée $task2->{duration} avec pour range $task2->{processors} qui commence à $task2->{starting_time}\n";
$space->tycat();

$task1 = $space->add_task(0,1,3);
print STDERR "__________________AJOUT tache de durée 1 avec 3 cpu\n";
$space->tycat();
$task2 = $space->add_task(0,4,5);
print STDERR "__________________AJOUT tache de durée 4 avec 5 cpu\n";
$space->tycat();
my $task3 = $space->add_task(0,10,3);
print STDERR "__________________AJOUT tache de durée 10 avec 4 cpu\n";
$space->tycat();
$space->remove_task($task1->{starting_time},$task1->{duration},$task1->{processors});
print STDERR "__________________SUPPRIME tache de durée $task1->{duration} avec pour range $task1->{processors} qui commence à $task1->{starting_time}\n";
$space->tycat();
$space->remove_task($task2->{starting_time},$task2->{duration},$task2->{processors});
print STDERR "__________________SUPPRIME tache de durée $task2->{duration} avec pour range $task2->{processors} qui commence à $task2->{starting_time}\n";
$space->tycat();
$space->remove_task($task->{starting_time},$task->{duration},$task->{processors});
print STDERR "__________________SUPPRIME tache de durée $task->{duration} avec pour range $task->{processors} qui commence à $task->{starting_time}\n";
$space->tycat();
$space->remove_task($task3->{starting_time},$task3->{duration},$task3->{processors});
print STDERR "__________________SUPPRIME tache de durée $task3->{duration} avec pour range $task3->{processors} qui commence à $task3->{starting_time}\n";
$space->tycat();



print STDERR "Done\n";
