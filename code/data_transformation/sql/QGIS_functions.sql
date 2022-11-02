-- visualisatie buffers and points small linestrings (in bgt_paasheuvel)
-- Buffer is used to determine close Lidar points to each interpolated BGT point. All points in this buffer can be used to determine the height of the BGT point. 
select st_collect(ST_Buffer(geompoint,10, 'quad_segs=8'), geompoint)
from bgt_geompoints
limit 10

-- Visualisation vonoroi polygons of lidar datapoints. First 3d lidar points have to be transf to 2d points. After QGIS function voronoi can be executed on these points.
select geometry(lidarpoint)
from lidar_geompoints
limit 10

-- voronoy diagram was realised with the build in voronoi diagram tool in QGIS. 
