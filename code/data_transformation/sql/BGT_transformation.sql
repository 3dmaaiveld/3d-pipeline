-- Create nieuw table interpolated_linestrings. Now the exterior/outer ring of all polygons are interpolated intro a multipoint 'linestring'. 
-- The multipoint and its corresponding start, begin and end point are saved in the new table. Important is that the corresponding polygons 'id' are saved, so the transformation can be backtracked to the original topology.
-- (ST_AsEWKT transforms a geometry object to a more readable object.)
CREATE TABLE interpolated_linestrings (
    poly geometry,
    linestr geometry,
    startpoint geometry,
    endpoint geometry);

INSERT INTO interpolated_linestrings (poly,linestr,startpoint,endpoint)
SELECT ST_GeomFromWKB(wkb_geometry), 
ST_AsEWKT(ST_LineInterpolatePoints(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))),
(5 / ST_Length(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))))  ))),
ST_StartPoint(ST_LineInterpolatePoints(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))),
(5 / ST_Length(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))))  ))),
ST_EndPoint(ST_LineInterpolatePoints(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))),
(5 / ST_Length(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))))  )))
FROM road_wegdeelactueelbestaand_0
limit 100

--insert BGT geometry points from code above into new database
create table bgt_geomPoints
(
   geomPoint geometry
);

INSERT INTO bgt_geomPoints ( geomPoint ) 
select (ST_DumpPoints(linestr)).geom
from interpolated_linestrings

-- de bgt geompoints hebben geen srid waardoor ze niet met lidar points vergeleken kunnen worden. Vandaar dat ze zelfde srid moeten krijgen als van lidar points:
UPDATE bgt_geompoints SET geompoint = ST_SetSRID(geompoint,28992)


-------------------------- INTERMIDATE STEPS --------------------------
-- Get all linestrings of bgt geoms
select ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry))), ST_GeomFromWKB(wkb_geometry)
from road_wegdeelactueelbestaand_0
limit 10;

-- Interpolate real linestring of bgt polygon
-- interpolate where the string linestring is replaced by the real linestrings in the BGT
-- st_linemerge is used for multilinestrings (single linestring is req as input for interpolate)
SELECT ST_AsEWKT(ST_GeomFromWKB(wkb_geometry)), ST_Dump(ST_LineInterpolatePoints(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))),
                                        (25 / ST_Length(ST_LineMerge(ST_AsEWKT(ST_ExteriorRing(ST_GeomFromWKB(wkb_geometry)))))  )))
FROM road_wegdeelactueelbestaand_0
limit 10

--retrieve BGT points from multipoints/linestr
select linestr, (ST_DumpPoints(linestr)).geom
from interpolated_linestrings
limit 10