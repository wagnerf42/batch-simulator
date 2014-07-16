filename<-commandArgs(TRUE)[1]
output_filename<-commandArgs(TRUE)[2]
data<-scan(filename)
pdf(output_filename)
hist(data)


