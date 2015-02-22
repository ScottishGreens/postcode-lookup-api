class PostcodeLookupService

  def self.lookup(postcode)

    sql = <<-SQL
    SELECT
      p.postcode as postcode,
      c.name as constituency,
      w.name as ward,
      r.name as region
    FROM 
      public.postcodes as p

      JOIN scotland_and_wales_const_region as c ON ST_Intersects(p.location, c.geog) IS true
      JOIN scotland_and_wales_region_region as r ON ST_Intersects(p.location, r.geog) IS true
      JOIN district_borough_unitary_ward_region as w ON ST_Intersects(p.location, w.geog) IS true

    WHERE
      p.postcode = '#{postcode}'
    SQL

    areas = ActiveRecord::Base.connection.execute(sql)
    return areas.first
  end

end
