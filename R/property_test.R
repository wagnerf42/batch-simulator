filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
data<-read.table(filename)
pdf(output_filename)
plot(data$V1, data$V3)

