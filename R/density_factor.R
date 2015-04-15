library(sm)

filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
instances<-commandArgs(TRUE)[3]
data<-read.table(filename,header=TRUE)
pdf(output_filename)

tmp_data = c(data$FIRST_LOCF, data$BECONT_LOCF, data$BELOC_LOCF, data$CONT_LOCF)
groups = c(rep(1, instances), rep(2, instances), rep(3, instances), rep(4, instances))
line_types = c(1, 5, 2, 4)
colors = c(1, 1, 1, 1)
labels = c("Basic backfilling", "Best effort contiguous", "Best effort local", "Forced contiguous")

sm.density.compare(tmp_data, groups, xlab="Locality factor", lty=line_types, col=colors, xlim=c(0.95,1.25), lwd=2)
title(main="Locality factor distribution by algorithm")
legend("topright", labels, lty=line_types, col=colors, lwd=2)


