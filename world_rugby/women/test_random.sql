select npl.parameter,npl.type,npl.level,nbf.estimate
from wr._women_parameter_levels npl
left outer join wr._women_basic_factors nbf
  on (nbf.factor,nbf.level,nbf.type)=(npl.parameter,npl.level,npl.type)
where npl.type='random'
order by parameter,level;
