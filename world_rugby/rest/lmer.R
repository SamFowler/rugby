sink("diagnostics/rest.txt")

library(lme4)
library(RPostgreSQL)

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv,host="localhost",port="5432",dbname="rugby")

query <- dbSendQuery(con, "
select
distinct
r.game_id,
r.year,
r.field as field,
        
r.team_id as team,
r.team_name as team_name,
r.opponent_id as opponent,

r.team_score as gs,

(case when r.team_rest is null then 8
      when r.team_rest>8 then 8
      when r.team_rest<3 then 3
      else r.team_rest
end) as team_rest,

(case when r.opponent_rest is null then 8
      when r.opponent_rest>8 then 8
      when r.opponent_rest<3 then 3
      else r.opponent_rest
end) as opponent_rest,

--(year-2007) as w
1 as w

from wr.results r

join wr.tiers t1
  on (t1.team_id)=(r.team_id)
join wr.tiers t2
  on (t2.team_id)=(r.opponent_id)

--where
--    r.year between 2008 and 2011

--and r.team_rest>3
--and r.opponent_rest>3

/*
and r.team_id in
(
select
team_id
from wr.results
where year between 2008 and 2011
group by team_id
having count(*)>9
)

and r.opponent_id in
(
select
team_id
from wr.results
where year between 2008 and 2011
group by team_id
having count(*)>9
)
*/

;")

sg <- fetch(query,n=-1)

dim(sg)

games <- sg[rep(row.names(sg), sg$w), ]

dim(games)

#games <- as.data.frame(do.call("rbind",gw))
#rm(sg)

attach(games)

pll <- list()

# Fixed parameters

field <- as.factor(field)
field <- relevel(field, ref = "neutral")

team_rest <- as.factor(team_rest)
opponent_rest <- as.factor(opponent_rest)

fp <- data.frame(field,team_rest,opponent_rest)
fpn <- names(fp)

# Random parameters

game_id <- as.factor(game_id)

offense <- as.factor(team)

defense <- as.factor(opponent)

rp <- data.frame(offense,defense)
rpn <- names(rp)

for (n in fpn) {
  df <- fp[[n]]
  level <- as.matrix(attributes(df)$levels)
  parameter <- rep(n,nrow(level))
  type <- rep("fixed",nrow(level))
  pll <- c(pll,list(data.frame(parameter,type,level)))
}

for (n in rpn) {
  df <- rp[[n]]
  level <- as.matrix(attributes(df)$levels)
  parameter <- rep(n,nrow(level))
  type <- rep("random",nrow(level))
  pll <- c(pll,list(data.frame(parameter,type,level)))
}

# Model parameters

parameter_levels <- as.data.frame(do.call("rbind",pll))
dbWriteTable(con,c("wr","_parameter_levels"),parameter_levels,row.names=TRUE)

g <- cbind(fp,rp)
g$gs <- gs
g$w <- w

detach(games)

dim(g)

model0 <- gs ~ field+(1|offense)+(1|defense)+(1|game_id)
model <- gs ~ field+team_rest+opponent_rest+(1|offense)+(1|defense)+(1|game_id)

fit0 <- glmer(model0, data=g, verbose=TRUE, family=poisson(link=log)) #, weights=w)
fit <- glmer(model, data=g, verbose=TRUE, family=poisson(link=log)) #, weights=w)

anova(fit0,fit)

fit
summary(fit)

# List of data frames

# Fixed factors

f <- fixef(fit)
fn <- names(f)

# Random factors

r <- ranef(fit)
rn <- names(r) 

results <- list()

for (n in fn) {

  df <- f[[n]]

  factor <- n
  level <- n
  type <- "fixed"
  estimate <- df

  results <- c(results,list(data.frame(factor,type,level,estimate)))

 }

for (n in rn) {

  df <- r[[n]]

  factor <- rep(n,nrow(df))
  type <- rep("random",nrow(df))
  level <- row.names(df)
  estimate <- df[,1]

  results <- c(results,list(data.frame(factor,type,level,estimate)))

 }

combined <- as.data.frame(do.call("rbind",results))

dbWriteTable(con,c("wr","_basic_factors"),as.data.frame(combined),row.names=TRUE)

quit("no")
