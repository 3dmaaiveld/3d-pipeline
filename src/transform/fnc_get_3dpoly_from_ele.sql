-- =======================================================================
-- function 
create or replace function maaiveld3d.get_polygonz(p_element_id int)
   returns geometry
   language plpgsql
  as
$$
declare 
-- variable declaration
polygon3d geometry;
begin
 -- logic
select 
st_polygon(st_linemerge(g2),7415) geom 
into polygon3d
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
		where b.element_id = p_element_id
		) point3d
	group by 	
		line_id , element_id
) line3d 
group by element_id
) poly
group by element_id,g2;
--
return polygon3d;
end;
$$
;