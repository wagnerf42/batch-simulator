filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]

data<-read.table(filename)
pdf(output_filename)
hist(data$V1, main=output_filename)

