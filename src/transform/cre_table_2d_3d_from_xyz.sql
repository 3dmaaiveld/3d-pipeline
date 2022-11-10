drop table if exists maaiveld3d.schollenbrugstraat_3d;
create table maaiveld3d.schollenbrugstraat_3d as 
    (select *, st_setsrid(ST_MakePoint(x::numeric,y::numeric),28992)::geometry('point',28992) as geometry_2d,  st_setsrid(ST_MakePoint(x::numeric,y::numeric,z::numeric),7415)::geometry('pointZ',7415) as geometry_3d 
    from maaiveld3d.schollenbrugstraat_xyz);
drop index if exists schollenbrugstraat_2d_gindx;
create index schollenbrugstraat_2d_gindx on maaiveld3d.schollenbrugstraat_3d using gist(geometry_2d);
drop index if exists schollenbrugstraat_3d_gindx;
create index schollenbrugstraat_3d_gindx on maaiveld3d.schollenbrugstraat_3d using gist(geometry_3d);

vacuum analyse maaiveld3d.schollenbrugstraat_3d;
