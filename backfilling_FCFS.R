data<-read.table("backfilling_FCFS.csv")
pdf("backfilling_FCFS.pdf")
hist(data$V1/data$V3, main="Histogram", xlab="Value of the ratio", col="gray")


