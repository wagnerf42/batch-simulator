# libraries
library(ggplot2)

# clean workspace
rm(list=ls());

#default values
input_file <- 'run_from_file_instances-50-2000-240-16-346/run_from_file_instances-50-2000-240-16-346-0.csv';
title <- 'test';

# input parameters
#input_file <- commandArgs(TRUE)[1];
#output_file <- commandArgs(TRUE)[2];
#title <- commandArgs(TRUE)[3];

# helper function for the error
sem <- function(x) {
  sd(x)/sqrt(length(x));
}

# read simulation data
data <- data.frame(read.table(input_file));

# order jobs by increasing Cmax for each simulation instance
for(row in 1:length(data[,1])) {
  data[row,] <- data[row,order(data[row,])];
}
rm(row);

# compute statistical estimators
mean_val <- array();
sd_val <- array();
error_val <- array();
sem_val <- array();

for (i in 1:length(data[1,])) {
  mean_val[i] <- mean(data[,i]);
  sd_val[i] <- sd(data[,i]);
  sem_val[i] <- sem(data[,i]);
  error_val[i] <- qt(0.975, df=(length(data[,i])-1))*sd_val[i]/sqrt(length(data[,1]));
}
rm(i);

## put in shape to plot
values <- data.frame(id=seq_along(mean_val), mean=mean_val, error=error_val, sem=sem_val);

# generate a smaller array
values2 <- values[seq(1, length(values[,1]), 10),];

# fix the ids, if that is intended
#values2$id <- seq(1, length(values2[,1]));

plot_val <- ggplot(values2, aes(x=id, y=mean));

# step or line
#plot_val <- plot_val + geom_step();
#plot_val <- plot_val + geom_line();

#scale and title
##plot_val <- plot_val + scale_y_log10();
plot_val <- plot_val + labs(title=title);

#plot_val <- plot_val + geom_smooth(aes(ymax=mean+error, ymin=mean-error));

#plot_val <- plot_val + geom_line(aes(y=mean+error));
#plot_val <- plot_val + geom_line(aes(y=mean-error));

plot_val <- plot_val + geom_pointrange(aes(ymax=mean+error, ymin=mean-error));

#ggsave(filename=output_file, plot=plot_val);
plot_val
