--
-- deriive outer ring from polygons
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

-- segment exterior ring by 1 meter
drop table if exists maaiveld3d.er_seg_wegdeel_line;
create table maaiveld3d.er_seg_wegdeel_line as
--let op curve defaults vanuit bgt landelijke voorziening! st_split maakt hier bruikbare lijnstukken van.
with mper as (
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
                where 1=1
                )
select 
    er.lokaalid,
    er.element_id, 
    (st_dump(st_split(st_snap(er.exteriorring, mper.bladepoints,0.002),mper.bladepoints))).geom as geometrie
from maaiveld3d.road_wegdeelactueelbestaand_er er
join mper
    on  er.lokaalid = mper.lokaalid and er.element_id = mper.element_id
where 1=1
--and er.lokaalid = 'G0363.29bbe83355844a42b5927950ffc6aa18'
;
--
alter table maaiveld3d.er_seg_wegdeel_line add column id serial primary key;--
alter table maaiveld3d.er_seg_wegdeel_line add column start_node int;--
alter table maaiveld3d.er_seg_wegdeel_line add column end_node int;--
--
--
--tussen tabel voor opbouwen topologie: nodes
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
--tussen tabel voor opbouwen topologie: edges
drop table if exists maaiveld3d.edges;
create table maaiveld3d.edges as
select
    l.lokaalid,
    st_length(l.geometrie) as lengte,
    l.geometrie,
    l.id as line_id,
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
--
-- selectie pointcloud per node 

-- buffer node
-- select intersectie met nodebuffer en gerelateerd bgtvlak
-- relateer intersectie met nodebuffer en gerelateerd bgtvlak met pointcloud

drop table if exists temp_nodes_buffer1m;
create temporary table temp_nodes_buffer1m
as 
select distinct 
	a.id,
	b.lokaalid ,
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
create index temp_nodes_buffer1m_gidx on temp_nodes_buffer1m using gist (geometrie);
vacuum analyze temp_nodes_buffer1m;

drop table if exists maaiveld3d.rel_nodes_naphoogte;
create table maaiveld3d.rel_nodes_naphoogte
as
select distinct 
	a.id,
	a.lokaalid ,
	b.z::numeric nap_hoogte,
	st_buffer(a.geometrie,1)
from
	temp_nodes_buffer1m a
join 
	maaiveld3d.schollenbrugstraat_3d b 
	on st_intersects(a.geometrie,b.geometry_2d)
order by a.id
;
