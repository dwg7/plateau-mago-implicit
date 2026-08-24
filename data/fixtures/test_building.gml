<?xml version="1.0" encoding="UTF-8"?>
<!--
  Test fixture: minimal CityGML building for unit tests.
  This is a synthetic example used only for testing inspect_citygml.py.
  It is NOT a real PLATEAU dataset sample.
  Released under CC0 1.0.
-->
<CityModel xmlns="http://www.opengis.net/citygml/2.0"
           xmlns:gml="http://www.opengis.net/gml"
           xmlns:bldg="http://www.opengis.net/citygml/building/2.0"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <gml:boundedBy>
    <gml:Envelope srsName="http://www.opengis.net/def/crs/EPSG/0/6668" srsDimension="3">
      <gml:lowerCorner>42.599 143.099 0.0</gml:lowerCorner>
      <gml:upperCorner>42.601 143.101 10.0</gml:upperCorner>
    </gml:Envelope>
  </gml:boundedBy>
  <cityObjectMember>
    <bldg:Building gml:id="BLD_FIXTURE_001">
      <bldg:measuredHeight uom="m">8.5</bldg:measuredHeight>
      <bldg:storeysAboveGround>2</bldg:storeysAboveGround>
      <bldg:yearOfConstruction>2000</bldg:yearOfConstruction>
      <bldg:usage>401</bldg:usage>
      <bldg:lod1Solid>
        <gml:Solid gml:id="BLD_FIXTURE_001_LOD1">
          <gml:exterior>
            <gml:CompositeSurface>
              <gml:surfaceMember>
                <gml:Polygon gml:id="P001">
                  <gml:exterior>
                    <gml:LinearRing>
                      <gml:posList srsDimension="3">
                        42.599 143.099 0.0
                        42.601 143.099 0.0
                        42.601 143.101 0.0
                        42.599 143.101 0.0
                        42.599 143.099 0.0
                      </gml:posList>
                    </gml:LinearRing>
                  </gml:exterior>
                </gml:Polygon>
              </gml:surfaceMember>
              <gml:surfaceMember>
                <gml:Polygon gml:id="P002">
                  <gml:exterior>
                    <gml:LinearRing>
                      <gml:posList srsDimension="3">
                        42.599 143.099 8.5
                        42.601 143.099 8.5
                        42.601 143.101 8.5
                        42.599 143.101 8.5
                        42.599 143.099 8.5
                      </gml:posList>
                    </gml:LinearRing>
                  </gml:exterior>
                </gml:Polygon>
              </gml:surfaceMember>
            </gml:CompositeSurface>
          </gml:exterior>
        </gml:Solid>
      </bldg:lod1Solid>
    </bldg:Building>
  </cityObjectMember>
</CityModel>
