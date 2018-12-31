<xsl:stylesheet version="2.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- 
  XQuery Content Management Library

  Author: Stéphane Sire <s.sire@opppidoc.fr>

  Script to convert Selector elements (data types) to CSV tables

  Use it offline with SaxonHE XSLT processor or any other one
  For instance to export data type in data/global-information/reuters-en.xml :

  java -cp {SAXON-HOME}/saxon9he.jar net.sf.saxon.Transform -s:../data/countries-en.xml -xsl:selector2csv.xsl selector=Countries lang=de

  To use the language comparison mode add a mode="multi" parameter and concatenate your selector files 
  under a common root (e.g. using "cat countries*.xm > countries.xml" then editing the file with nano to 
  add a Collection root, then processing the countries.xml file with this script)

  The language comparison mode is only compatible with Selectors with Groups

  TODO: 
    - implement language comparison mode for simple Selectors w/o Groups
    - manages Selector with Group type in "full" export

  -->

<xsl:output method="text" encoding="iso-8859-1"/>

<xsl:strip-space elements="*" />

<xsl:param name="selector"/>
<xsl:param name="lang">en</xsl:param>
<xsl:param name="mode">mono</xsl:param> 

<xsl:param name="delim" select="','" />
<xsl:param name="quote" select="'&quot;'" />
<xsl:param name="break" select="'&#xA;&#xD;'" />

<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="$mode = 'mono'">
      <!-- one language extraction -->
      <xsl:choose>
        <xsl:when test="$selector != ''"><xsl:apply-templates select=".//Description[@Lang = $lang]/Selector[@Name = $selector]"/></xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select=".//Description[@Lang = $lang]/Selector" mode="full"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <!-- multiple languages extraction -->
      <xsl:choose>
        <xsl:when test="$selector != ''"><xsl:apply-templates select="/" mode="languages"/></xsl:when>
        <xsl:otherwise>
          <xsl:text>you MUST specify a selector !</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ***************************** -->
<!-- Language comparison dump mode -->
<!-- ***************************** -->

<xsl:template match="/" mode="languages">
  <xsl:value-of select="concat($quote, 'Value', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, //Description[Selector[@Name = $selector][count(preceding::Selector[Group]) = 0]]/@Lang, $quote)" />
  <xsl:for-each select="//Selector[@Name = $selector][count(preceding::Selector[Group]) > 0]">
    <xsl:value-of select="$delim" />
    <xsl:value-of select="concat($quote, ../@Lang, $quote)" />
  </xsl:for-each>
  <xsl:value-of select="$break" />
  <xsl:apply-templates select="//Description/Selector[@Name = $selector]" mode="languages"/>
</xsl:template>

<xsl:template match="Selector[count(preceding::Selector[Group]) = 0]" mode="languages">
  <!-- first pass no Group -->
  <xsl:apply-templates select="Group" mode="languages">
    <xsl:sort select="Value" data-type="text"/>
  </xsl:apply-templates>
  <!-- second pass no sub-selectors for each Group -->
  <xsl:apply-templates select="Group/Selector" mode="languages-inner-selector"/>
</xsl:template>

<xsl:template match="Selector[count(preceding::Selector[Group]) > 0]" mode="languages">
</xsl:template>

<xsl:template match="Group" mode="languages">
  <xsl:variable name="key" select="Value"/>
  <xsl:value-of select="concat($quote, Value, $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, Name, $quote)" />
  <xsl:for-each select="//Selector[@Name = $selector][count(preceding::Selector[Group]) > 0]">
    <xsl:value-of select="$delim" />
    <xsl:value-of select="concat($quote, Group[Value = $key]/Name, $quote)" />
  </xsl:for-each>
  <xsl:value-of select="$break" />
</xsl:template>

<xsl:template match="Selector" mode="languages-inner-selector">
  <xsl:value-of select="concat($quote, '-', ancestor::Group/Value ,'-', $quote)" />
  <xsl:value-of select="$break" />
  <xsl:apply-templates select="Option" mode="languages-inner-selector">
    <xsl:sort select="Value" data-type="text"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="Option" mode="languages-inner-selector">
  <xsl:param name="outer-key"><xsl:value-of select="ancestor::Group/Value"/></xsl:param>
  <xsl:variable name="inner-key" select="Value"/>
  <xsl:value-of select="concat($quote, Value, $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, Name, $quote)" />
  <xsl:for-each select="//Selector[@Name = $selector][count(preceding::Selector[Group]) > 0]/Group[Value = $outer-key]/Selector">
    <xsl:value-of select="$delim" />
    <xsl:value-of select="concat($quote, Option[Value = $inner-key]/Name, $quote)" />
  </xsl:for-each>
  <xsl:value-of select="$break" />
</xsl:template>

<!-- ************************* -->
<!-- Single Language dump mode -->
<!-- ************************* -->

<xsl:template match="Selector[Group]">
  <xsl:value-of select="concat($quote, 'Value', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, 'Group', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, 'SubValue', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, 'SubGroup', $quote)" />
  <xsl:value-of select="$break" />
  <xsl:apply-templates select="Group" />
</xsl:template>

<xsl:template match="Group">
  <xsl:apply-templates select="Selector/Option" mode="hierarchical">
    <xsl:sort select="Value" data-type="number"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="Selector[not(Group)]">
  <xsl:value-of select="concat($quote, 'Value', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, 'Name', $quote)" />
  <xsl:value-of select="$break" />
  <xsl:apply-templates select="Option" mode="flat">
    <xsl:sort select="Value" data-type="number"/>
  </xsl:apply-templates>
</xsl:template>

<!-- First with headers -->
<xsl:template match="Selector[1][not(Group)]" mode="full" priority="1">
  <xsl:value-of select="concat($quote, 'Type', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, 'Value', $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, 'Name', $quote)" />
  <xsl:value-of select="$break" />
  <xsl:apply-templates select="Option" mode="flat">
    <xsl:sort select="Value" data-type="number"/>
  </xsl:apply-templates>

</xsl:template>

<!-- Don't repeat headers -->
<xsl:template match="Selector[not(Group)]" mode="full">
  <xsl:apply-templates select="Option" mode="flat">
    <xsl:sort select="Value" data-type="text"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="Option" mode="hierarchical">
  <xsl:value-of select="concat($quote, ./ancestor::Group/Value, $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, ./ancestor::Group/Name, $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, Value, $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, Name, $quote)" />
  <xsl:value-of select="$break" />
</xsl:template>

<xsl:template match="Option" mode="flat">
  <xsl:if test="$selector = ''">
    <xsl:value-of select="concat($quote, ./ancestor::Selector/@Name, $quote)" />
    <xsl:value-of select="$delim" />
  </xsl:if>
  <xsl:value-of select="concat($quote, Value, $quote)" />
  <xsl:value-of select="$delim" />
  <xsl:value-of select="concat($quote, Name, $quote)" />
  <xsl:value-of select="$break" />
</xsl:template>

<xsl:template match="text()" />

</xsl:stylesheet>