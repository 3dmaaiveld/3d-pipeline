--
-- selectie pointcloud per node 
-- buffer node
-- select intersectie met nodebuffer en gerelateerd bgtvlak
-- relateer intersectie met nodebuffer en gerelateerd bgtvlak met pointcloud

drop table if exists temp_nodes_buffer1m;
create temporary table temp_nodes_buffer1m
as 
select distinct 
	a.id node_id,
	b.lokaalid ,
    b.element_id,
    b.line_id,
	st_intersection(st_buffer(a.geometrie,1),st_buffer(c.geometrie_vlak,0)) geometrie
from
	maaiveld3d.nodes a
join 
	maaiveld3d.edges b 
	on a.id = b.startnode or  a.id = b.end_node 
join 
	maaiveld3d.road_wegdeelactueelbestaand_0 c 
	on b.lokaalid = c.lokaalid 
;
--
create index temp_nodes_buffer1m_gidx on temp_nodes_buffer1m using SPGIST (geometrie);
create index temp_nodex_idx1 on temp_nodes_buffer1m(node_id);
vacuum analyze temp_nodes_buffer1m;
--
-- creatie relatietabel nodes en naphoogte
drop table if exists maaiveld3d.rel_nodes_naphoogte;
create table maaiveld3d.rel_nodes_naphoogte
as
select 
	node_id,
	lokaalid,
    element_id,
    line_id,
	avg(nap_hoogte) gem_naphoogte 
from (
select --distinct 
	a.node_id,
	a.lokaalid ,
    a.element_id,
    a.line_id,
	b.z::numeric nap_hoogte
	--st_buffer(a.geometrie,1)
from
	temp_nodes_buffer1m a
join 
	maaiveld3d.schollenbrugstraat_exec_sql_xyz b -- lidar points
	on st_intersects(a.geometrie,b.geometry_2d)
) nodehgt
group by 
	node_id,
    element_id,
    line_id,
	lokaalid
;
--
-- ============================================================================
-- Er komen nodes voor zonder hoogte, geef deze de hoogte de het meest nabije punt binnen hetzelfde object
-- selecteer alle bgt objecten waar gezocht moet worden naar hoogte
-- en relateer deze met ahn4 laz
--
drop table if exists maaiveld3d.hlp_rel_bgt_ahn4;
create table maaiveld3d.hlp_rel_bgt_ahn4
as
with bgt_geen_hoogte as (
						select distinct e.lokaalid 
						from
							maaiveld3d.nodes n 
						join 
							maaiveld3d.edges e 
							on n.id = e.startnode or n.id =e.end_node
						left join 
							maaiveld3d.rel_nodes_naphoogte h 
							on n.id = h.node_id 
						)
select
	a.lokaalid,
	c.id ahn4_id,
	c.z,
	c.geometry_2d 
from
	maaiveld3d.road_wegdeelactueelbestaand_0 a
inner join
	bgt_geen_hoogte b 
	on a.lokaalid = b.lokaalid 
left join 
	maaiveld3d.schollenbrugstraat_exec_sql_xyz c 
	on st_intersects(a.geometrie_vlak,c.geometry_2d)
where 
	c.z is not null 
;
--
--
--
-- Wanneer er nog bgt objecten zijn zonder enige relatie met ahn4, zoek deze binnen een buffer van 2 meter en voeg toe aan relatie bgt-ahn4
drop table if exists tmp_bgt_geenhoogte;
create temporary table tmp_bgt_geenhoogte
as
with bgt_geen_hoogte as (
							select distinct e.lokaalid 
							from
								maaiveld3d.nodes n 
							join 
								maaiveld3d.edges e 
								on n.id = e.startnode or n.id =e.end_node
							left join 
								maaiveld3d.rel_nodes_naphoogte h 
								on n.id = h.node_id 
							where not exists (select 'x' from maaiveld3d.hlp_rel_bgt_ahn4 h where e.lokaalid=h.lokaalid)
							)
select
	a.lokaalid,
	c.id ahn4_id,
	c.z,
	c.geometry_2d 
from
	maaiveld3d.road_wegdeelactueelbestaand_0 a
inner join
	bgt_geen_hoogte b 
	on a.lokaalid = b.lokaalid 
left join 
	maaiveld3d.schollenbrugstraat_exec_sql_xyz c 
	on st_intersects(st_buffer(a.geometrie_vlak,2),c.geometry_2d)
where 
	c.z is not null 
;
--
-- insert..
insert into maaiveld3d.hlp_rel_bgt_ahn4 SELECT * from tmp_bgt_geenhoogte;
--
create index hlp_rel_bgt_ahn4_gidx on maaiveld3d.hlp_rel_bgt_ahn4 using gist (geometry_2d);
vacuum analyze maaiveld3d.hlp_rel_bgt_ahn4;
--
-- ----------------------------------------------------------------------------
-- Zoek bij de nodes  die in de eerste fase geen hoogte kregen een hoogte binnen het object. 
-- In enkele gevallen buiten het object..
-- select alle nodes without a z-value in rel_nodes_naphoogte and assign a z-value
-- list with nodes without z-value
drop table if exists tmp_nodes_aanvhoogte; 
create TEMPORARY table  tmp_nodes_aanvhoogte 
as
with nodes_geen_hoogte as (
							select distinct n.id 
							from
								maaiveld3d.nodes n 
							join 
								maaiveld3d.edges e 
								on n.id = e.startnode or n.id = e.end_node
							left join 
								maaiveld3d.rel_nodes_naphoogte h 
								on n.id = h.node_id 
							where 
								h.gem_naphoogte is null
							)
--
-- select join and filter 
-- relation node , edges and bgt object 
select  distinct
	nds.id node_id,
	edg.lokaalid ,
    edg.element_id,
    edg.line_id,
    nap.z 
from
	maaiveld3d.nodes nds
join 
	maaiveld3d.edges edg 
	on nds.id = edg.startnode or  nds.id = edg.end_node 
join 
	nodes_geen_hoogte geen 
	on nds.id = geen.id
CROSS JOIN LATERAL 
	(select nap.z , nap.geometry_2d <-> nds.geometrie as dist 
	 from maaiveld3d.hlp_rel_bgt_ahn4 as nap
	 where edg.lokaalid =nap.lokaalid 
	 order by dist 
	 limit 1) nap
;

-- insert into rel_nodes_naphoogte
insert into maaiveld3d.rel_nodes_naphoogte 
select * from  tmp_nodes_aanvhoogte;
--
--
-- temp table with 3d polygons 
--
drop table if exists maaiveld3d.tmp_poly3d;
create table maaiveld3d.tmp_poly3d 
AS
select distinct
element_id,
st_polygon(st_linemerge(g2),7415) geom 
from (
select 
	element_id,
	--line_id,
	st_union( ST_LineFromMultiPoint(geometry_3d)) g2
from (
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
) line3d 
where lower(st_geometrytype(geometry_3d)) like '%multi%'
group by element_id
) poly
group by element_id,g2
;
--
create index tmp_poly3d_idx on maaiveld3d.tmp_poly3d(element_id);
vacuum analyze maaiveld3d.tmp_poly3d;


-- final table
drop table if exists maaiveld3d.road_wegdeelactueelbestaand_n0_3d;
create table maaiveld3d.road_wegdeelactueelbestaand_n0_3d
as
select distinct
	c.geom geometrie3d,
	a.fid,
	a.lokaalid,
	a.objectbegintijd,
	a.objecteindtijd,
	a.tijdstipregistratie,
	a.eindregistratie,
	a.lv_publicatiedatum,
	a.bronhouder,
	a.inonderzoek,
	a.relatievehoogteligging,
	a.bgt_status,
	a.plus_status,
	a.bgt_functie,
	a.plus_functie,
	a.bgt_fysiekvoorkomen,
	a.plus_fysiekvoorkomen,
	a.wegdeeloptalud
from
	maaiveld3d.road_wegdeelactueelbestaand_0 a 
join 
	maaiveld3d.er_seg_wegdeel_line b 
	on a.lokaalid = b.lokaalid 
join 
    maaiveld3d.tmp_poly3d c 
    on b.element_id = c.element_id
;
--
vacuum analyze maaiveld3d.road_wegdeelactueelbestaand_n0_3d;

