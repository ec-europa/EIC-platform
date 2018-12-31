<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>
  
  <xsl:template name="Stats">
    <xsl:param name="anal"/>
    <h2>
      Who: <xsl:value-of select="count($anal//Person)"/> Persons (incl. <xsl:value-of select="count($anal//Person/@KAM)"/> KAMs)<br/>
      Assigment(s): <xsl:value-of select="count($anal/CoachAssigned//Code)"/> since <xsl:value-of select="$anal/CoachAssigned/@Min"/><br/>
      Search(es): <xsl:value-of select="count($anal//Person//Purpose[@What = 'Standalone'])"/> standalones / <xsl:value-of select="count($anal//Person//Purpose[@What = 'Coach Assignment'])"/> through C.A. form.
    </h2>
  </xsl:template>

  <!-- Single Check screen - at least contains an empty <Check/>  -->
  <xsl:template match="/Analytics">
    <site:view>
      <site:title><title>Case Tracker/Coach Match Analytics</title></site:title>
      <site:content>
        <h1>Case Tracker/Coach Match Analytics</h1>
        <xsl:call-template name="Stats">
          <xsl:with-param name="anal" select="."/>
        </xsl:call-template>
        <a href="./analytics.xlsx?export=1" target="_blank" class="btn btn-primary export">Generate Excel (Labels)</a><a href="./analytics.xlsx?export=2" target="_blank" class="btn btn-primary export">Generate Excel (Values)</a>
        <table class="table table-bordered" style="font-size:12px" localized="1">
          <caption>KAM's searches</caption>
          <thead>
            <tr>
              <th style="width:200px" rowspan="2">WHO</th>
              <th style="width:300px" rowspan="2">WHEN / TYPE / RESULTS</th>
              <th style="width:300px" rowspan="2">Related Tasks</th>
              <th style="width:300px">
                <xsl:attribute name="colspan"><xsl:value-of select="count(Mask//Field)"/></xsl:attribute>
                Criteria
              </th>
            </tr>
            <tr>
              <xsl:for-each select="Mask//Field">
                <th style="width:20px">
                  <xsl:attribute name="style">background-color:<xsl:value-of select="../@Color"/></xsl:attribute>
                  <xsl:value-of select="."/>
                </th>
              </xsl:for-each>
            </tr>
          </thead>
          <tbody>
            <xsl:apply-templates select="Person"/>
          </tbody>
        </table>
      </site:content>
    </site:view>
  </xsl:template>
  
  <xsl:template match="Person">
    <xsl:variable name="kid"><xsl:value-of select="Id"/></xsl:variable>
    <!-- first row (full) -->
    <xsl:variable name="row1" select="Row[position() = 1]"/>
    <tr>
      <td>
        <xsl:if test="count(Row) > 1"><xsl:attribute name="rowspan"><xsl:value-of select="count(Row)"/></xsl:attribute></xsl:if>
        <xsl:apply-templates select="@Name"/>
      </td>
      <xsl:call-template name="DisplayRow">
        <xsl:with-param name="row" select="$row1"/>
        <xsl:with-param name="mask" select="/Analytics/Mask"/>
      </xsl:call-template>
    </tr>
    <!-- subsequent rows (for each single search) -->
    <xsl:for-each select="Row[position() > 1]">
      <xsl:variable name="row" select="."/>
      <tr>
        <!-- kam name spanning all searches -->
        <xsl:call-template name="DisplayRow">
          <xsl:with-param name="row" select="$row"/>
          <xsl:with-param name="mask" select="/Analytics/Mask"/>
        </xsl:call-template>
      </tr>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="DisplayRow">
    <xsl:param name="row"/>
    <xsl:param name="mask"/>
    <td>
      <xsl:value-of select="$row/Purpose/@Timestamp"/> / <xsl:value-of select="$row/Purpose/@What"/> / <b><xsl:value-of select="$row/Count"/> Coach(es)</b><br/>
      <xsl:if test="$row/Request/@Was = 'RSbF'"><i>Refined Search</i><br/></xsl:if>
      <xsl:if test="$row/Request/Keywords">
        Searched keyword: "<xsl:value-of select="upper-case($row/Request/Keywords)"/>"
      </xsl:if>
    </td>
    <td>
      <xsl:for-each select="$row/Purpose/Case">
        <xsl:apply-templates select="."/>
        <xsl:choose><xsl:when test="position() != last()"><hr></hr></xsl:when></xsl:choose>
      </xsl:for-each>
    </td>
    <xsl:for-each select="$mask//Field">
      <xsl:variable name="field"><xsl:value-of select="."/></xsl:variable>
      <xsl:variable name="match" select="$row/Request/*[local-name(.) = $field]"/>
      <td>
        <xsl:choose>
          <xsl:when test="$match/@_Display">
            <xsl:call-template name="elements">
              <xsl:with-param name="elts" select="tokenize($match/@_Display, ';;')"/>
            </xsl:call-template>
            <!--<xsl:if test="$match/@Expertise">
              <xsl:text> </xsl:text>(<xsl:call-template name="Expertise"><xsl:with-param name="exp" select="$match/@Expertise"></xsl:with-param></xsl:call-template>)
            </xsl:if>-->
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="$match/text() != ''"><xsl:value-of select="$match"/></xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="style">background-color:#efeded;</xsl:attribute></xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="elements">
    <xsl:param name="elts"/>
    <xsl:choose>
      <xsl:when test="count($elts) = 1"><xsl:value-of select="$elts"/></xsl:when>
      <xsl:otherwise>
        <ul>
          <xsl:for-each select="$elts">
            <li><xsl:value-of select="."/></li>
          </xsl:for-each>
        </ul>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="Case">
    <xsl:variable name="case" select="."/>
    <div>
      <i><a href="../projects/{@Project}"><xsl:value-of select="@Project"/></a> (<xsl:value-of select="PIC"/>)</i><br/>
    <xsl:for-each select="child::*[not(local-name(.) = 'PIC')]">
      <div>
        <xsl:call-template name="context-color">
          <xsl:with-param name="name" select="local-name(.)"></xsl:with-param>
        </xsl:call-template>
        <xsl:variable name="activity" select="."/>
        <a href="../projects/{$case/@Project}/cases/{$activity/@Case}/activities/{$activity/@Activity}"><xsl:value-of select="local-name(.)"/></a>
        <xsl:if test="@Delay">(delay <xsl:value-of select="@Delay"/>)</xsl:if><br/>
        <xsl:choose>
          <xsl:when test="$activity/Criteria">
            <xsl:variable name="criteria" select="$activity/Criteria"/>
            <xsl:for-each select="/Analytics/Mask/Group[@Matchable]">
              <xsl:variable name="group" select="."/>
              <table class="table">
                <thead>
                  <tr>
                    <xsl:for-each select="Field">
                      <xsl:variable name="field" select="."/>
                      <th>
                        <xsl:variable name="exist" select="$criteria//*[local-name(.) = $field/@Match]"/>
                        <xsl:choose>
                          <xsl:when test="empty($exist)"><xsl:attribute name="style">width:10px; border: 2px solid <xsl:value-of select="$group/@Color"/>; background-color: black</xsl:attribute></xsl:when>
                          <xsl:otherwise>
                            <xsl:choose>
                              <xsl:when test="not($exist/@Match)"><xsl:attribute name="style">width:10px; border: 2px solid <xsl:value-of select="$group/@Color"/>; background-color: white</xsl:attribute></xsl:when>
                              <xsl:otherwise><xsl:attribute name="style">width:10px; border: 2px solid black; background-color: <xsl:value-of select="$group/@Color"/></xsl:attribute></xsl:otherwise>
                            </xsl:choose>
                          </xsl:otherwise>
                        </xsl:choose>
                      </th>
                    </xsl:for-each>
                  </tr>
                </thead>
              </table>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise><b style="color:red">No activity yet</b></xsl:otherwise>
        </xsl:choose>
      </div>
      <br/>
    </xsl:for-each>
    </div>
  </xsl:template>
  
  <xsl:template name="context-color">
    <xsl:param name="name"/>
    <xsl:if test="contains('Possible Trial Match', $name)">
      <xsl:attribute name="style">background-color: #8bff79</xsl:attribute>
    </xsl:if>
    <xsl:if test="'After' = $name">
      <xsl:attribute name="style">background-color: ffdc79</xsl:attribute>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="Expertise">
    <xsl:param name="exp"/>
    <xsl:if test="$exp eq '1'">low</xsl:if>
    <xsl:if test="$exp eq '2'">mid.</xsl:if>
    <xsl:if test="$exp eq '3'">high</xsl:if>
  </xsl:template>
  
  <xsl:template match="@Name[. = ''][parent::KAM]" priority="1">
    <i>Not in DB (probably deleted profile)</i>
  </xsl:template>
  
  <xsl:template match="@Name[parent::KAM]">
    <xsl:value-of select="."/>
  </xsl:template>
</xsl:stylesheet>
