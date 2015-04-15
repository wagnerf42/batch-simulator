library(sm)

filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
instances<-commandArgs(TRUE)[3]
data<-read.table(filename,header=TRUE)
pdf(output_filename)

tmp_data = c(data$FIRST_CONTJ, data$BECONT_CONTJ, data$BELOC_CONTJ, data$LOC_CONTJ)
groups = c(rep(1, instances), rep(2, instances), rep(3, instances), rep(4, instances))
line_types = c(1, 5, 2, 4)
colors = c(1, 1, 1, 1)
sm.density.compare(tmp_data, groups, xlab="Number of contiguous jobs", lty=line_types, col=colors, xlim=c(170,280), lwd=2)
labels = c("Basic backfilling", "Best effort contiguous", "Best effort local", "Forced local")
legend("topright", labels, lty=line_types, col=colors, lwd=2)
title(main="Contiguous jobs distribution by algorithm")

