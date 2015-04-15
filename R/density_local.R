library(sm)

filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
instances<-commandArgs(TRUE)[3]
data<-read.table(filename,header=TRUE)
pdf(output_filename)

tmp_data = c(data$FIRST_LOCJ, data$BECONT_LOCJ, data$BELOC_LOCJ, data$CONT_LOCJ)
groups = c(rep(1, instances), rep(2, instances), rep(3, instances), rep(4, instances))
labels = c("Basic backfilling", "Best effort contiguous", "Best effort local", "Forced contiguous")
line_types = c(1, 5, 2, 4)
colors = c(1, 1, 1, 1)

sm.density.compare(tmp_data, groups, xlab="Number of local jobs", col=colors, lty=line_types, xlim=c(100,320), lwd=2)
legend("topright", labels, lty=line_types, col=colors, lwd=2)
title(main="Local jobs distribution by algorithm")

