filename<-commandArgs(TRUE)[1])
data<-read.table(filename)
pdf("backfilling_FCFS.pdf")
hist(data$V1/data$V2, main="Histogram", xlab="Value of the ratio", col="gray")


