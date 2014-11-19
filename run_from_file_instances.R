# libraries
library(ggplot2)

# clean workspace
rm(list=ls());

#default values
#file <- 'run_from_file_instances-0.csv'
#output_file <- 'run_from_file_instances-0.pdf';
#input_title <- 'test';

# input parameters
file<-commandArgs(TRUE)[1];
output_file<-commandArgs(TRUE)[2];
input_title<-commandArgs(TRUE)[3];

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

# compute statistical estimators
mean_val <- array();
median_val <- array();
min_val <- array();
max_val <- array();
ratio_val <- array();

for (i in 1:length(data[1,])) {
  mean_val[i] <- mean(data[,i]);
  median_val[i] <- median(data[,i]);
  min_val[i] <- min(data[,i]);
  max_val[i] <- max(data[,i]);
  ratio_val[i] <- (max_val[i] - min_val[i])/mean_val[i];
}
rm(i);

# put in shape to plot
values <- data.frame(id=seq_along(mean_val), mean=mean_val, median=median_val, min=min_val, max=max_val, ratio=ratio_val);

plot_val <- ggplot(values, aes(x=id, y=values$ratio));
plot_val <- plot_val + geom_step();
#plot_val <- plot_val + scale_y_log10();
plot_val <- plot_val + labs(title=input_title)

ggsave(filename=output_file, plot=plot_val);

