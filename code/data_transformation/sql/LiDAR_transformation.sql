-- Create database for lidar geometry points, and insert converted geometry points
-- Lidar data is saved as pcpoints. This is inconvenient when BGT objects are geometry types.
-- So the meshes are unpacked and transformed to 3D geometry points. 
CREATE TABLE Lidar_geomPoints (
    lidarPoint geometry
);

INSERT INTO lidar_geomPoints (lidarPoint)
SELECT
ST_AsEWKT(geometry(PC_Explode(pa)))
FROM paasheuvel;


-- Get closest point (POC) (selects lidar point closest to bgt point) (from gives every combination between lidar and bgt).
-- Note that lidar points still have to be flatten from 3d to 2d to ignore height in the distance to the BGT points.
-- In order to get select bgt and lidar points, they have to be in the same database. So a backup of the bgt_geompoints 
-- were made and restored in the database that contains the LiDAR data. 
select ST_AsEWKT(bgt_geompoints.geompoint), ST_AsEWKT(ST_ClosestPoint(lidar_geompoints.lidarpoint,bgt_geompoints.geompoint))
from bgt_geompoints,lidar_geompoints
limit 100


-------------------------- INTERMIDATE STEPS --------------------------

-- Get 2d points of 3d lidar points (used for function closest point to bgt point)
select ST_Point(ST_X(lidarpoint),ST_Y(lidarpoint))
from lidar_geomPoints
limit 10

-------------------------- KMEANS Clustering --------------------------
--This code creates a new table with 15 clusters and classifies all lidarpoint to a specific cluster (cid). 
--The purpose of this code is to identify homogeneous data when it comes to xy-position and hight.
--Clusters can later be reorganized as polygons with help of the Voronoi Polygon tool in QGIS.
CREATE TABLE kmeans15 AS
(SELECT p.*, ST_ClusterKMeans(p.lidarpoint, 15) OVER() cid
 FROM lidar_geompoints as p)
