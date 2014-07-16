filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
data<-read.table(filename)
pdf(output_filename)
hist(data$V1/data$V2, main=output_filename, xlab="Ratio", col="gray")


