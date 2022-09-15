--multi polygons (aantal holes)

select
    lokaalid,
    --ST_ExteriorRing(geometrie_vlak) as ering,
    sum(ST_NumInteriorRings(geometrie)) as aantal_holes
from
    (select lokaalid, (ST_Dump(geometrie_vlak)).geom as geometrie from bron_bgtnl.wegdeelactueelbestaand) as aap
group by 
    lokaalid
having sum(ST_NumInteriorRings(geometrie)) notnull 
order by 
    sum(ST_NumInteriorRings(geometrie)) desc
;    


--single/regular polygon ()

select
    lokaalid,
    --ST_ExteriorRing(geometrie_vlak) as ering,
    ST_NumInteriorRings(geometrie_vlak) as aantal_holes
from bron_bgtnl.wegdeelactueelbestaand
where 1=1
and ST_NumInteriorRings(geometrie_vlak) notnull
and ST_NumInteriorRings(geometrie_vlak) > 1

order by ST_NumInteriorRings(geometrie_vlak) desc;

--select the exterior ring geometry from regular donuts polygons
select
    *, ST_ExteriorRing(geometrie_vlak) AS exteriorring

  from (      select *, ST_NumInteriorRings(geometrie_vlak) as aantal_holes
        from bron_bgtnl.wegdeelactueelbestaand
        where 1=1
        and ST_NumInteriorRings(geometrie_vlak) notnull
        and ST_NumInteriorRings(geometrie_vlak) > 1
        ) sub
 ;   
 --select the exterior ring geometry from multi donuts polygons:
 SELECT 
    lokaalid, 
    ST_Collect(ST_ExteriorRing(geometrie)) AS exteriorring
FROM (SELECT 
        lokaalid, 
        (ST_Dump(geometrie_vlak)).geom As geometrie
        FROM bron_bgtnl.wegdeelactueelbestaand
        ) As aap
GROUP BY 
    lokaalid
having ST_Collect(ST_ExteriorRing(geometrie)) notnull 

    
;
-- select the interior ring geometry from regular donut polygons
select
    lokaalid, st_interiorringn(geometrie_vlak,1) AS interiorring

  from (      select *, ST_NumInteriorRings(geometrie_vlak) as aantal_holes
        from bron_bgtnl.wegdeelactueelbestaand
        where 1=1
        and ST_NumInteriorRings(geometrie_vlak) notnull
        and ST_NumInteriorRings(geometrie_vlak) > 1
        ) sub
 ;   

 -- select the interior ring geometry from multi donut polygons
SELECT 
    lokaalid, 
    ST_Collect(st_interiorringn(geometrie,1)) AS interiorring
FROM (SELECT 
        lokaalid, 
        (ST_Dump(geometrie_vlak)).geom As geometrie
        FROM bron_bgtnl.wegdeelactueelbestaand
        ) As aap
GROUP BY 
    lokaalid
having ST_Collect(st_interiorringn(geometrie,1)) notnull ;

