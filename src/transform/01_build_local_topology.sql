--
-- derive outer ring from polygons
drop table if exists maaiveld3d.road_wegdeelactueelbestaand_er;
create table maaiveld3d.road_wegdeelactueelbestaand_er 
as
select 
	fid,
	gml_id,
	"namespace",
	lokaalid,
	objectbegintijd,
	objecteindtijd,
	tijdstipregistratie,
	eindregistratie,
	lv_publicatiedatum,
	bronhouder,
	inonderzoek,
	relatievehoogteligging,
	bgt_status,
	plus_status,
	bgt_functie,
	plus_functie,
	bgt_fysiekvoorkomen,
	plus_fysiekvoorkomen,
	wegdeeloptalud,
	st_exteriorring(geometrie_vlak) exteriorring
from
        (
        select 
            fid,
            gml_id,
            "namespace",
            lokaalid::varchar,
            objectbegintijd,
            objecteindtijd,
            tijdstipregistratie,
            eindregistratie,
            lv_publicatiedatum,
            bronhouder,
            inonderzoek,
            relatievehoogteligging,
            bgt_status,
            plus_status,
            bgt_functie,
            plus_functie,
            bgt_fysiekvoorkomen,
            plus_fysiekvoorkomen,
            wegdeeloptalud,
            (st_dump(geometrie_vlak)).geom geometrie_vlak 
        from (
                select
                    fid,
                    gml_id,
                    "namespace",
                    lokaalid,
                    objectbegintijd,
                    objecteindtijd,
                    tijdstipregistratie,
                    eindregistratie,
                    lv_publicatiedatum,
                    bronhouder,
                    inonderzoek,
                    relatievehoogteligging,
                    bgt_status,
                    plus_status,
                    bgt_functie,
                    plus_functie,
                    bgt_fysiekvoorkomen,
                    plus_fysiekvoorkomen,
                    wegdeeloptalud,
                    st_buffer(geometrie_vlak,0) geometrie_vlak
                from
                    maaiveld3d.road_wegdeelactueelbestaand_0
                ) mv 
        order by fid
        ) subele 
;
--
create index road_wegdeelactueelbestaand_er_gidx on maaiveld3d.road_wegdeelactueelbestaand_er using gist (exteriorring);
alter table  maaiveld3d.road_wegdeelactueelbestaand_er
add column element_id serial primary key;
vacuum analyze maaiveld3d.road_wegdeelactueelbestaand_er;


-- create table to clip the lines (blade)
drop table if exists maaiveld3d.tmp_stg_blade;
create table maaiveld3d.tmp_stg_blade
as 
select distinct 
    lokaalid,
    element_id,
    bladepoints
from (
select
    lokaalid,
    element_id,
    case 
        when st_length(exteriorring) > 2
            then ST_LineInterpolatePoints(exteriorring, (1/st_length(exteriorring))) 
            else ST_LineInterpolatePoints(exteriorring, (0.05/st_length(exteriorring)))
        end bladepoints --om de 1 m (mes=blade)
from
    maaiveld3d.road_wegdeelactueelbestaand_er -- extrior ring
) blade 
;
--
create index tmp_stg_blade_gidx on maaiveld3d.tmp_stg_blade using gist (bladepoints);
alter table maaiveld3d.tmp_stg_blade add column id serial PRIMARY key;
vacuum analyze maaiveld3d.tmp_stg_blade;
--
-- add vertexpoints to the blade 
drop table if exists tmp_vertexpoints;
create temporary table tmp_vertexpoints 
as 
with vertexpoints as (
select distinct
    lokaalid,
    element_id,
    (ST_DumpPoints(exteriorring)).geom bladepoints
from
    maaiveld3d.road_wegdeelactueelbestaand_er) 
--
select distinct
    a.lokaalid,
    a.element_id,
    a.bladepoints
from 
	vertexpoints a
left join 
	maaiveld3d.tmp_stg_blade b
	on st_DWithin(a.bladepoints, b.bladepoints,0.001) 
where 
	coalesce(a.bladepoints <-> b.bladepoints,1) > 0.001
;
--
insert into maaiveld3d.tmp_stg_blade
select * from tmp_vertexpoints;
--
--
-- again, remove duplicate points and union points
drop table if exists maaiveld3d.tmp_blade;
create table maaiveld3d.tmp_blade
as 
select 
    lokaalid,
    element_id,
    st_union(bladepoints) bladepoints
from (
select
distinct on (lokaalid,element_id,bladepoints)
    lokaalid,
    element_id,
    bladepoints
from maaiveld3d.tmp_stg_blade
) multi 
group by 
    lokaalid,
    element_id 
;
--
create index tmp_blade_gidx on maaiveld3d.tmp_blade using gist (bladepoints);
vacuum analyze maaiveld3d.tmp_blade;
--
--
-- segment exterior ring by 1 meter
drop table if exists maaiveld3d.er_seg_wegdeel_line;
create table maaiveld3d.er_seg_wegdeel_line as
--let op curve defaults vanuit bgt landelijke voorziening! st_split maakt hier bruikbare lijnstukken van.
select distinct
    er.lokaalid,
    er.element_id, 
    (st_dump(st_split(st_snap(er.exteriorring, mper.bladepoints,0.002),mper.bladepoints))).geom as geometrie
from maaiveld3d.road_wegdeelactueelbestaand_er er
join maaiveld3d.tmp_blade mper
    on  er.lokaalid = mper.lokaalid and er.element_id = mper.element_id
;
--
alter table maaiveld3d.er_seg_wegdeel_line add column id serial primary key;--
alter table maaiveld3d.er_seg_wegdeel_line add column start_node int;--
alter table maaiveld3d.er_seg_wegdeel_line add column end_node int;--
--
--
-- tabel voor opbouwen locale topologie: nodes
drop table if exists maaiveld3d.nodes;
create table maaiveld3d.nodes as
select 
    st_startpoint(geometrie) geometrie
from maaiveld3d.er_seg_wegdeel_line
union 
select 
    st_endpoint(geometrie) geometrie
from
    maaiveld3d.er_seg_wegdeel_line
;
alter table maaiveld3d.nodes add column id serial primary key;
--
--
create index nodes_gidx on maaiveld3d.nodes using gist (geometrie);
vacuum analyze maaiveld3d.nodes;
-- nodes relateren aan de lines, subelements en bgt_objecten
--
--tussentabel voor opbouwen topologie: edges
drop table if exists maaiveld3d.edges;
create table maaiveld3d.edges as
select
    l.lokaalid,
    st_length(l.geometrie) as lengte,
    l.geometrie,
    l.id as line_id,
    l.element_id,
    n1.id as startnode,
    n2.id as end_node
from
    maaiveld3d.er_seg_wegdeel_line l
join 
    maaiveld3d.nodes n1 --startnode
    on st_Dwithin(st_startpoint(l.geometrie),n1.geometrie, 0.0002) --1/2 mm zoek radius
join    
    maaiveld3d.nodes n2 --endnode
    on 
    st_Dwithin(st_endpoint(l.geometrie),n2.geometrie, 0.0002) ----1/2 mm zoek radius
;
--