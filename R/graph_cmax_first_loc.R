filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
data<-read.table(filename,header=TRUE)
pdf(output_filename)
plot(data$FIRST_CMAX, data$LOC_CMAX, main="Makespan distribution for basic backfilling and forced local", xlab="Makespan for basic backfilling (seconds)", ylab="Makespan for forced local (seconds)")
abline(0, 1)
