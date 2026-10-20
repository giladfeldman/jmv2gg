# Synthetic example, not research results.
study <- data.frame(condition=factor(rep(c("A","B"),20)),score=sin(1:40)+(1:40)/30)
result <- jmv2gg::convert_code('jmv::ANOVA(data=study,dep="score",factors="condition")',engine="ggplot2")
writeLines(result$text,"editable-comparison.R")
