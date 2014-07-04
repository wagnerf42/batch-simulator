data<-read.table("backfilling_FCFS.csv")
pdf("backfilling_FCFS.pdf")
hist(data$Backfilling/data$FCFS, main="Histogram", xlab="Value of the ratio")


