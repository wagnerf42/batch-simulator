# libraries
library(ggplot2)

# clean workspace
rm(list=ls());

#default values
#file <- 'run_from_file_instances-0.csv'
#output_file <- 'run_from_file_instances-0.pdf';
#input_title <- 'test';

# input parameters
file <- commandArgs(TRUE)[1];
output_file <- commandArgs(TRUE)[2];
input_title <- commandArgs(TRUE)[3];

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
sd_val <- array();
error_val <- array();
error_p_val <- array();
error_m_val <- array();

for (i in 1:length(data[1,])) {
  mean_val[i] <- mean(data[,i]);
  sd_val[i] <- sd(data[,i]);
  error_val[i] <- qt(0.975, df=(length(data[,i])-1))*sd_val[i]/sqrt(length(data[,1]));
  error_p_val[i] <- mean_val[i] + error_val[i];
  error_m_val[i] <- mean_val[i] - error_val[i];
}
rm(i);

# put in shape to plot
values <- data.frame(id=seq_along(mean_val), mean=mean_val, error_p=error_p_val, error_m=error_m_val);

plot_val <- ggplot(values, aes(x=id, y=values$mean));
plot_val <- plot_val + geom_step();
plot_val <- plot_val + geom_step(aes(y=error_p)) + geom_step(aes(y=error_m));
#plot_val <- plot_val + scale_y_log10();
plot_val <- plot_val + labs(title=input_title)

ggsave(filename=output_file, plot=plot_val);

