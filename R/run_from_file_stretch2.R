# libraries
library(ggplot2)

# clean workspace
rm(list=ls());

#default values
#csv_file <- "run_from_file_stretch-84640-16-9-first.csv";
#csv_file2 <- "run_from_file_stretch-84640-16-9-first.csv";
#trace_file <- "../../../swf/CEA-Curie-2011-2.1-cln-b1-clean.swf";

# argument values
csv_file <- commandArgs(TRUE)[1];
csv_file2 <- commandArgs(TRUE)[2];
trace_file <- commandArgs(TRUE)[3];
output_file <- commandArgs(TRUE)[4];

trace_data <- read.table(trace_file);

wait_time_val <- as.numeric(read.table(csv_file));
wait_time_val2 <- as.numeric(read.table(csv_file2));

id_val <- seq(1, length(wait_time_val));
cum_wait_time_val <- cumsum(wait_time_val);
cum_wait_time_val2 <- cumsum(wait_time_val2);
mean_val <- (cum_wait_time_val2-cum_wait_time_val)/id_val;

plot_data <- data.frame(id=id_val, mean=mean_val);
plot_val <- ggplot(plot_data, aes(x=id, y=mean));
plot_val <- plot_val + labs(title=csv_file2);
plot_val <- plot_val + geom_step();

#plot_val
ggsave(filename=output_file, plot=plot_val);


