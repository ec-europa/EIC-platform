<xsl:stylesheet version="2.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- 

  Utility script used to prepare iso3166-countries-en.xml

  Convert countries.xml file from http://publications.europa.eu/mdr/authority/country/index.html
  to an hybrid code-3166-1-alpha-2 / code-3166-1-alpha-3 Selector suitable for converting 
  countries-*.xml / world-countries-*.xml codes (e.g. web service sanitization)

  Pre-requisite: to be run from selector root folder

  Sample command :

  java -cp {SAXON-HOME}/saxon9he.jar net.sf.saxon.Transform -s:../raw/countries.xml -xsl:migrations/iso-countries.xsl

  Post-treatment:
  - delete Store="OK" attributes
  - manually add Store="legacy" correspondance for all MISSING options

  Validation (invariants):

  count(<code-3166-1-alpha-2 Store="OK">) + count(MISSING/Countries) = count(Countries)
  count(<code-3166-1-alpha-3 Store="OK">) + count(MISSING/ISO3Countries) = count(ISO3Countries)

  -->

<xsl:output method="xml" media-type="text/xml" encoding="utf-8" omit-xml-declaration="yes" indent="yes"/>

  <xsl:strip-space elements="*" />

  <xsl:variable name="alpha2">
    <xsl:for-each select="//record[@deprecated = 'false']/code-3166-1-alpha-2">
      <xsl:sort select="."/>
      <xsl:value-of select="concat(string(.), ' ')"/>
    </xsl:for-each>
  </xsl:variable>

  <xsl:variable name="alpha3">
    <xsl:for-each select="//record[@deprecated = 'false']/code-3166-1-alpha-3">
      <xsl:sort select="."/>
      <xsl:value-of select="concat(string(.), ' ')"/>
    </xsl:for-each>
  </xsl:variable>
  
  <xsl:variable name="country2">
    <xsl:for-each select="document('../data/countries-en.xml')//Option/Value">
      <xsl:sort select="."/>
      <xsl:value-of select="concat(string(.), ' ')"/>
    </xsl:for-each>
  </xsl:variable>

  <xsl:variable name="country3">
    <xsl:for-each select="document('../data/world-countries-en.xml')//Option/Value">
      <xsl:sort select="."/>
      <xsl:value-of select="concat(string(.), ' ')"/>
    </xsl:for-each>
  </xsl:variable>
  
  <xsl:template match="/">
    <Selector Name="ISO3166Countries">
      <Title>International standard for country codes ISO 3166</Title>
      <Source>http://publications.europa.eu/mdr/authority/country/index.html</Source>
      <CONTROL>
        <ALPHA-2-SET Total="{count(//record/code-3166-1-alpha-2)}"><xsl:copy-of select="$alpha2"/></ALPHA-2-SET>
        <ALPHA-3-SET Total="{count(//record/code-3166-1-alpha-3)}"><xsl:copy-of select="$alpha3"/></ALPHA-3-SET>
        <COUNTRY-2-SET Total="{count(document('../data/countries-en.xml')//Option/Value)}"><xsl:copy-of select="$country2"/></COUNTRY-2-SET>
        <COUNTRY-3-SET Total="{count(document('../data/world-countries-en.xml')//Option/Value)}"><xsl:copy-of select="$country3"/></COUNTRY-3-SET>
        <MISSING>
          <Countries>
            <xsl:apply-templates select="document('../data/countries-en.xml')//Option[not(contains($alpha2, concat(Value, ' ')))]" mode="miss"/>
          </Countries>
          <ISO3Countries>
            <xsl:apply-templates select="document('../data/world-countries-en.xml')//Option[not(contains($alpha3, concat(Value, ' ')))]" mode="miss"/>
          </ISO3Countries>
        </MISSING>
      </CONTROL>
      <xsl:apply-templates select="countries/record"/>
    </Selector>
  </xsl:template>

  <xsl:template match="Option" mode="miss">
    <xsl:copy-of select="."/>
  </xsl:template>

  <xsl:template match="record[@deprecated = 'true']">
  </xsl:template>

  <xsl:template match="record[@deprecated = 'false']">
    <Option>
      <xsl:apply-templates select="code-3166-1-alpha-2"/>
      <xsl:apply-templates select="code-3166-1-alpha-3"/>
      <xsl:apply-templates select="label/lg.version[@lg = 'eng']"/>
    </Option>
  </xsl:template>

  <xsl:template match="code-3166-1-alpha-2">
    <xsl:variable name="code"><xsl:value-of select="."/></xsl:variable>
    <code-3166-1-alpha-2>
      <xsl:choose>
        <xsl:when test="document('../data/countries-en.xml')//Option[Value eq $code]"><xsl:attribute name="Store">OK</xsl:attribute></xsl:when>
        <xsl:otherwise></xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="."/>
    </code-3166-1-alpha-2>
  </xsl:template>

  <xsl:template match="code-3166-1-alpha-3">
    <xsl:variable name="code"><xsl:value-of select="."/></xsl:variable>
    <code-3166-1-alpha-3>
    <xsl:choose>
      <xsl:when test="document('../data/world-countries-en.xml')//Option[Value eq $code]"><xsl:attribute name="Store">OK</xsl:attribute></xsl:when>
      <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="."/>
    </code-3166-1-alpha-3>
    <Value>
      <xsl:choose>
        <xsl:when test="document('../data/world-countries-en.xml')//Option[Value eq $code]"><xsl:attribute name="Store">OK</xsl:attribute></xsl:when>
        <xsl:otherwise></xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="."/>
    </Value>
  </xsl:template>

  <xsl:template match="lg.version">
    <Name><xsl:value-of select="."/></Name>
  </xsl:template>

</xsl:stylesheet>

