# Writes the synthetic "replication study" dataset bundled with the app and
# the package. Every value is simulated (fixed seed); no participant data.
# Run from the package root: Rscript tools/examples/make-replication-data.R
set.seed(20261022)
n <- 240
framing <- factor(rep(c("gain", "loss"), each = n / 2), levels = c("gain", "loss"))
source <- factor(rep(rep(c("expert", "peer", "none"), each = n / 6), 2), levels = c("expert", "peer", "none"))
age <- round(runif(n, 18, 70))
education <- factor(sample(c("secondary", "bachelor", "postgraduate"), n, TRUE, prob = c(0.3, 0.45, 0.25)),
  levels = c("secondary", "bachelor", "postgraduate"))
latent <- rnorm(n)
trust <- round(4 + 0.5 * (framing == "loss") + c(expert = 0.6, peer = 0.2, none = 0)[as.character(source)] +
  0.4 * (framing == "loss") * (source == "expert") + 0.015 * (age - 40) + 0.6 * latent + rnorm(n, 0, 0.9), 2)
satisfaction <- round(3 + 0.45 * trust + 0.01 * age + rnorm(n, 0, 1), 2)
pre <- round(50 + 5 * latent + rnorm(n, 0, 6), 1)
mid <- round(pre + 2 + 2 * (framing == "loss") + rnorm(n, 0, 5), 1)
post <- round(mid + 1.5 + 2.5 * (framing == "loss") + rnorm(n, 0, 5), 1)
choice <- factor(ifelse(stats::plogis(-2 + 0.45 * trust + 0.5 * (framing == "loss")) > runif(n), "accept", "reject"),
  levels = c("reject", "accept"))
likert <- function(weight, reverse = FALSE) {
  value <- round(3 + weight * latent + rnorm(n, 0, 0.8))
  value <- pmin(5, pmax(1, value))
  if (reverse) 6 - value else value
}
attention <- factor(ifelse(runif(n) < 0.06, "fail", "pass"), levels = c("pass", "fail"))
study <- data.frame(
  id = sprintf("P%03d", seq_len(n)), framing, source, age, education, trust, satisfaction,
  pre, mid, post, choice,
  q1 = likert(0.9), q2 = likert(0.8), q3 = likert(0.85), q4 = likert(0.7, reverse = TRUE),
  q5 = likert(0.6), q6 = likert(0.75), attention
)
study$trust[c(7, 91)] <- NA
for (path in c("inst/examples/replication-study.csv", "web/public/examples/replication-study.csv")) {
  utils::write.csv(study, path, row.names = FALSE)
}
cat("Wrote", nrow(study), "rows,", ncol(study), "columns.\n")
