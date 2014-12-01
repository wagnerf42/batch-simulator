# clean workspace
rm(list=ls());

# libraries
library(ggplot2);

# default values
#commandArgs <- c('CEA-Curie-2011-2.1-cln-b1-clean.csv', 'METACENTRUM-2009-2-clean.csv');

# colorblind friendly colors
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7");

# helpers
trace.read <- function(file) {
  df = read.table(file);
  df$origin = file;
  return(df);
}

data.format <- function(raw_data) {
  tmp_data = raw_data[,1] * raw_data[,2] / 3600;
  return(data.frame(id=seq_along(tmp_data), work=cumsum(tmp_data), origin=raw_data$origin));
}

# put data in shape for plot
df_list <- list();
for (file in commandArgs(TRUE)) {
  df_list[[file]] = data.format(trace.read(file));
}
data <- do.call(rbind, df_list);

# express the plot
plot_data <- ggplot(data=data, aes(x=id, y=work, linetype=origin, colour=origin));
plot_line <- plot_data + geom_line() + scale_color_manual(values=cbPalette);
ggsave(filename="output.pdf", plot=plot_line);