- [x] Rewrite some of the platform code for the new experiment
  - [x] Make the platform package responsible for all things related to the
    platform

- [x] Platform level factor
  - [x] Add the platform level factor to the Schedule package
  - [x] Generate an example schedule with platform level factor
  - [x] Compare all the variants using the platform level factor
  - [x] Implement the code to stretch the job's run time

- [x] Implement the status for each job. I would like to know when a job is
  successful (when the real run time is smaller than the walltime) and when the
  job is not successful (when the job has to be killed because the real run
  time reached the walltime).
- [x] Do some checking on the job status when the trace is read from the file.
  I would like to know how many jobs are failing on the original trace as well
  on the new schedule.

- [ ] Compare all the variants using Cmax and Stretch with this stretch code
  - [x] Transfer all the code about contiguity and locality to the Platform
    package

- [ ] Real application times
  - [ ] Talk to Milliam about using real applications + BATSIM.
  - [ ] Implement the code for using real application
  - [ ] Run an example with real applications and all the variants
  - [ ] Design and run an experiment comparing all the variants

- [s] Cleanup the code
  - [x] Move as much as possible of the locality and contiguity code to the
  Platform package
  - [x] Review all the code base and use the better the idea of scalar and list
  context. Generally, code should be as flexible as possible, preserving the
  possibility of being used in list or scalar context.
  - [ ] Check if the that rule affects the performance in Perl.
  - [ ] Finish documenting the routines in the code.
  - [ ] Remove the log4perl usage where it's not needed. Leave only in places
    where you are likely to come back for debugging many times.
  - [ ] Review all the SVG code.
  - [ ] Check again if there are any memory leaks on the code.
