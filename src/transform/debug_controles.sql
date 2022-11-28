

-- ========================================================================
-- debug en controles 
/*
SELECT node_id, lokaalid, element_id, line_id, gem_naphoogte
FROM maaiveld3d.rel_nodes_naphoogte
where line_id = 26523;
*/
--
-- controleer edges (line_id) waarvan maar 1 node een hoogte heeft
select * from (
select
	node_id,
	lokaalid,
	element_id,
	line_id,
	count(node_id) over(partition by line_id) aantal_nodes,
	gem_naphoogte
from
	maaiveld3d.rel_nodes_naphoogte
where
	line_id = 26793
) nh 
where aantal_nodes !=2
;
--
--
-- geen multipoints
select mti.* from (
	select 
	    element_id,
		line_id ,
		st_union(geometry_3d) geometry_3d
	from (
		select
			a.id,
			b.lokaalid ,
            b.element_id,
            b.line_id,
            b.gem_naphoogte,
            -- create st_PointZ
			st_setSrid(ST_MakePoint(ST_X(a.geometrie), ST_Y(a.geometrie)::float, b.gem_naphoogte),7415) geometry_3d
		from
			maaiveld3d.nodes a
		inner join 
			maaiveld3d.rel_nodes_naphoogte b 
			on a.id = b.node_id 
		) point3d
	group by 	
		line_id , element_id
) mti 
--where line_id =10
where lower(st_geometrytype(geometry_3d)) not like'%multi%'
;


--
--

select
	lokaalid,
	lengte,
	geometrie,
	line_id,
	element_id,
	startnode,
	end_node
from
	maaiveld3d.edges
where line_id = 26523;


SELECT node_id, lokaalid, element_id, line_id, gem_naphoogte
FROM maaiveld3d.rel_nodes_naphoogte
where line_id = 26523;
-- 308 ontbreekt
--
--
select distinct e.lokaalid 
from
	maaiveld3d.nodes n 
join 
	maaiveld3d.edges e 
	on n.id = e.startnode or n.id =e.end_node
left join 
	maaiveld3d.rel_nodes_naphoogte h 
	on n.id = h.node_id 
;--where not exists (select 'x' from maaiveld3d.hlp_rel_bgt_ahn4 h where e.lokaalid=h.lokaalid)
--
--
--
select distinct 
n.id ,
e.line_id ,
h.gem_naphoogte 
from
	maaiveld3d.nodes n 
join 
	maaiveld3d.edges e 
	on n.id = e.startnode or n.id = e.end_node
left join 
	maaiveld3d.rel_nodes_naphoogte h 
	on n.id = h.node_id 
where n.id = 308
--where 
	--h.gem_naphoogte is null
order by n.id ;
--
-- onderstaande geeft twee nodes, 1 per line 
SELECT node_id, lokaalid, element_id, line_id, gem_naphoogte
FROM maaiveld3d.rel_nodes_naphoogte
where node_id =308;
