# York University campus POI loader

This is a custom tool I wrote to take POI data from JSON files used by York's online camps and convert it into something Avoirdupois can use.

It reads in JSON and constructs POI objects as it goes, and with each associates an Action or or category as necessary.

In theory it would be nice to be able to take the JSON data and convert it all into a YAML file, which the regular loader script could load, but it's easier just to shove the stuff all into the database directly like this.

The script may perhaps be useful in similar cases where data will be munged, turned into Avoirdupois POIS and shoved directly into the database.

## GeoJSON files

The GeoJSON conversion I did just because I wanted to see how the placemarks looked in GeoJSON and how the GitHub mapping rendered them.  As expected, it looks nice.  Maybe York will move to GeoJSON as a file format for its maps.

