# A synthetic replication study (simulated data, not participants): a
# 2 (framing) x 3 (source) between-subjects design with a covariate, three
# repeated measures, a binary choice and a six-item scale. Paste this into
# jmv2gg to get an editable figure for every analysis.
library(jmv)

study <- read.csv("replication-study.csv")
study$framing <- factor(study$framing, levels = c("gain", "loss"))
study$source <- factor(study$source, levels = c("expert", "peer", "none"))
study$education <- factor(study$education, levels = c("secondary", "bachelor", "postgraduate"))
study$choice <- factor(study$choice, levels = c("reject", "accept"))

# Exclusions: failed attention check
study <- study[study$attention == "pass", ]

# Descriptives
jmv::descriptives(data = study, vars = c("age", "trust", "education"), splitBy = "framing")

# Confirmatory: framing x source on trust
jmv::ANOVA(formula = trust ~ framing * source, data = study, emMeans = ~ framing:source)

# Adjusting for age
jmv::ancova(data = study, dep = "trust", factors = "framing", covs = "age")

# Two-group comparisons
jmv::ttestIS(data = study, vars = c("trust", "satisfaction"), group = "framing", welchs = TRUE)

# Change over time, by framing
jmv::anovaRM(
  data = study,
  rm = list(list(label = "time", levels = c("pre", "mid", "post"))),
  rmCells = list(
    list(measure = "pre", cell = "pre"),
    list(measure = "mid", cell = "mid"),
    list(measure = "post", cell = "post")
  ),
  bs = "framing"
)
jmv::ttestPS(data = study, pairs = list(list(i1 = "pre", i2 = "post")))

# Associations
jmv::corrMatrix(data = study, vars = c("trust", "satisfaction", "age", "pre", "post"))
jmv::linReg(
  data = study, dep = "satisfaction", covs = c("trust", "age"), factors = "framing",
  blocks = list(list("trust", "age"), list("framing"))
)
jmv::logRegBin(
  data = study, dep = "choice", covs = "trust", factors = "framing",
  blocks = list(list("trust", "framing"))
)
jmv::contTables(data = study, rows = "choice", cols = "source")

# Scale
jmv::reliability(data = study, vars = c("q1", "q2", "q3", "q4", "q5", "q6"), revItems = "q4")

# A ggstatsplot figure from the same study
ggstatsplot::ggbetweenstats(data = study, x = source, y = trust)
