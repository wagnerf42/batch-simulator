# libraries
library(ggplot2)

# clean workspace
rm(list=ls());

#default values
file <- 'run_from_file_instances-0.csv'
output_file <- 'run_from_file_instances-0.pdf';
input_title <- 'test';

# input parameters
#file <- commandArgs(TRUE)[1];
#output_file <- commandArgs(TRUE)[2];
#input_title <- commandArgs(TRUE)[3];

# helper function for the error
sem <- function(x) {
  sd(x)/sqrt(length(x));
}

# read simulation data
data <- data.frame(read.table(file));

# order jobs by increasing Cmax for each simulation instance
for(row in 1:length(data[,1])) {
  data[row,] <- data[row,order(data[row,])];
}
rm(row);

## compute statistical estimators
mean_val <- array();
sd_val <- array();
error_val <- array();

for (i in 1:length(data[1,])) {
  mean_val[i] <- mean(data[,i]);
  sd_val[i] <- sd(data[,i]);
  error_val[i] <- qt(0.975, df=(length(data[,i])-1))*sd_val[i]/sqrt(length(data[,1]));
}
rm(i);

## put in shape to plot
values <- data.frame(id=seq_along(mean_val), mean=mean_val, error=error_val);

# generate a smaller array
values2 <- values[seq(1, length(values[,1]), 20),];

# fix the ids, if that is intended
#values2$id <- seq(1, length(values2[,1]));

plot_val <- ggplot(values2, aes(id, mean));

# step or line
#plot_val <- plot_val + geom_step();
#plot_val <- plot_val + geom_line();

#scale and title
##plot_val <- plot_val + scale_y_log10();
plot_val <- plot_val + labs(title=input_title);

#plot_val <- plot_val + geom_smooth(aes(ymax=mean+error, ymin=mean-error));

#plot_val <- plot_val + geom_line(aes(y=mean+error));
#plot_val <- plot_val + geom_line(aes(y=mean-error));

plot_val <- plot_val + geom_pointrange(aes(ymax=mean+error, ymin=mean-error));

#ggsave(filename=output_file, plot=plot_val);
plot_val
