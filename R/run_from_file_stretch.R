# libraries
library(ggplot2)

# clean workspace
rm(list=ls());

#default values
#csv_file <- "run_from_file_stretch-84640-16-9-first.csv";
#trace_file <- "../../../swf/CEA-Curie-2011-2.1-cln-b1-clean.swf";

# argument values
csv_file <- commandArgs(TRUE)[1];
trace_file <- commandArgs(TRUE)[2];
output_file <- commandArgs(TRUE)[3];

trace_data <- read.table(trace_file);

wait_time_val <- as.numeric(read.table(csv_file));
id_val <- seq(1, length(wait_time_val));
cum_wait_time_val <- cumsum(trace_data$wait_time);

mean_val <- array();
sd_val <- array();
error_val <- array();

for (i in 1:length(wait_time_val)) {
  mean_val[i] <- mean(wait_time_val[1:i]);
  sd_val[i] <- sd(wait_time_val[1:i]);
  error_val[i] <- qt(0.975, df=(length(wait_time_val)-1))*sd_val[i]/sqrt(length(wait_time_val));
}

plot_data <- data.frame(id=id_val, mean=mean_val, sd=sd_val, error=error_val);
plot_val <- ggplot(plot_data, aes(x=id, y=mean));
plot_val <- plot_val + labs(title=csv_file);
plot_val <- plot_val + geom_linerange(aes(ymin=mean-error, ymax=mean+error));

#plot_val
ggsave(filename=output_file, plot=plot_val);


