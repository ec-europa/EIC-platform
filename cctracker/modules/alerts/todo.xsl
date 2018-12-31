<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/error">
    <site:view>
      <site:title><title>Case Tracker Alerts</title></site:title>
    </site:view>
  </xsl:template>

  <!-- Single Check screen - at least contains an empty <Check/>  -->
  <xsl:template match="/Checks[not(@User)]">
    <site:view>
      <site:title><title>Case Tracker Check #<xsl:value-of select="Check/@No"/></title></site:title>
      <site:content>
        <xsl:apply-templates select="Summaries"/>
        <xsl:apply-templates select="Check"/>
      </site:content>
    </site:view>
  </xsl:template>
  
  <xsl:template match="Summaries[position() = 1]">
    <table name="todo-kam" class="table table-bordered todo">
      <caption>KAM's to do list (click on a column header to sort the table)</caption>
      <thead>
        <tr>
          <th>Project ID</th>
          <th>Project Acronym</th>
          <th>SME beneficiary</th>
          <th>Country</th>
          <th>Funding</th>
          <th>KAM Coordinator</th>
          <th>KAM</th>
          <th>Coach</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="//Check/Project[ancestor::Summaries]">
          <xsl:sort select="KAM"/>
        </xsl:apply-templates>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Summaries[position() !=  1]" />

  <!-- All in one Check - may be empty  -->
  <xsl:template match="/Checks[@User]">
    <site:view>
      <site:title><title>Alerts for <xsl:value-of select="@User"/></title></site:title>
      <site:content>
        <h1>Case Tracker alerts for <xsl:value-of select="@User"/></h1>
        <xsl:choose>
          <xsl:when test="string(/Checks/@IsKC) = '1'">
            <h1>Coordinator of <xsl:value-of select="count(Summaries)"/> KAM's (<xsl:value-of select="count(Summaries[Check/Project[count(.) > 0]])"/> have duties / <xsl:value-of select="count(Summaries//Project)"/> cases)</h1>
            <div id="todos-export">
              <a download="todos-summary.xls" href="#" class="btn btn-primary export">Generate Excel</a>
              <a download="todos-summary.csv" href="#" class="btn btn-primary export">Generate CSV</a>
            </div>
          </xsl:when>
        </xsl:choose>
        <xsl:apply-templates select="Summaries">
          <xsl:sort select="substring-after(@User,' ')"/>
        </xsl:apply-templates>
        <xsl:choose>
          <xsl:when test="string(/Checks/@IsKC) = '1'">
            <h1><xsl:value-of select="@User"/>'s to do list</h1>
          </xsl:when>
        </xsl:choose>
        <xsl:apply-templates select="Check"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Check[parent::Checks]">
    <xsl:apply-templates select="@No"/>
    <p class="warning">Last check run at <xsl:value-of select="substring(@Timestamp, 12, 5)"/> on <xsl:value-of select="substring(@Timestamp, 1, 10)"/></p>
    <table id="test" class="table table-bordered todo">
      <caption><xsl:value-of select="@Title"/><xsl:apply-templates select="@Total"/><xsl:apply-templates select="@Threshold"/></caption>
      <thead>
        <tr>
          <th>Project ID</th>
          <th>Project Acronym</th>
          <th>SME beneficiary</th>
          <th>Country</th>
          <th>Funding</th>
          <xsl:choose>
            <xsl:when test="@When = 'Activity'">
              <th>KAM</th>
              <th>Coach</th>
            </xsl:when>
            <xsl:otherwise>
              <xsl:choose>
                <xsl:when test="@When = 'Case'">
                  <th>EEN KAM Coordinator</th>
                  <th>KAM</th>
                </xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
          <th style="min-width:4em">Nb of days</th>
        </tr>
      </thead>
      <tbody localized="1">
        <xsl:apply-templates select="Project">
          <xsl:sort select="Acronym"/>
        </xsl:apply-templates>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="@Threshold"><xsl:text> </xsl:text>threshold at <xsl:value-of select="."/> days
  </xsl:template>

  <xsl:template match="@No">
    <h1 style="margin-bottom:0">Check #<xsl:value-of select="."/></h1>
  </xsl:template>
  
  <xsl:template match="@No[/Checks/@User]">
    <h2 style="margin-bottom:0">Check #<xsl:value-of select="."/></h2>
  </xsl:template>
  
  <xsl:template match="@No[ancestor::Summaries]" priority="1">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@Total[number(.) > 1]"><xsl:text> </xsl:text>(<span class="over"><xsl:value-of select="."/> cases</span>)
  </xsl:template>

  <xsl:template match="@Total[number(.) = 1]"><xsl:text> </xsl:text>(<span class="over">1 case</span>)
  </xsl:template>

  <xsl:template match="@Total[number(.) = 0]"><xsl:text> </xsl:text>(<span class="ok">no case</span>)
  </xsl:template>

  <!-- =======================  Project > Cases*  ============================== -->
  <xsl:template match="Project">
    <tr>
      <td><xsl:value-of select="Id"/></td>
      <td><xsl:apply-templates select="Acronym"/></td>
      <td><xsl:apply-templates select="Case/SME"/></td>
      <td><xsl:apply-templates select="Case/Country"/></td>
      <td>
        <span style="display:block"><xsl:value-of select="Call/MasterCall"/></span>
        <span style="display:block"><xsl:value-of select="Call/CallRef"/></span>
        <span style="display:block"><xsl:value-of select="Call/FundingRef"/></span>
      </td>
      <xsl:choose>
        <xsl:when test="@ActivityNo">
          <td><xsl:value-of select="Case/KAM"/></td>
          <td><xsl:value-of select="Case/Coach"/></td>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="@CaseNo">
              <td><xsl:value-of select="Case/KC"/></td>
              <td><xsl:value-of select="Case/KAM"/></td>
            </xsl:when>
            <xsl:otherwise/>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
      <td>
        <xsl:choose>
          <xsl:when test="number(Run) > number(../@Threshold)">
            <xsl:attribute name="class">over</xsl:attribute>
            <span><xsl:value-of select="Run"/></span> (+<xsl:value-of select="number(Run)- number(../@Threshold)"/>)
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="Run"/>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
  </xsl:template>
  
  <xsl:template match="SME">
    <span style="display:block"><xsl:value-of select="."/></span>
  </xsl:template>
  
  <xsl:template match="Country">
    <span style="display:block"><xsl:value-of select="."/></span>
  </xsl:template>
  
  <xsl:template match="Summaries//Project">
    <tr>
      <td><xsl:value-of select="Id"/></td>
      <td><xsl:apply-templates select="Acronym"/></td>
      <td><xsl:value-of select="Case/SME"/></td>
      <td><xsl:value-of select="Case/Country"/></td>
      <td>
        <span style="display:block"><xsl:value-of select="Call/MasterCall"/></span>
        <span style="display:block"><xsl:value-of select="Call/CallRef"/></span>
        <span style="display:block"><xsl:value-of select="Call/FundingRef"/></span>
      </td>
      <td><xsl:value-of select="Case/KC"/></td>
      <td>
        <xsl:choose>
          <xsl:when test="ancestor::Summaries/@Username != ''">
            <a target="_blank" href="{/Checks/@Base}alerts/{../../@Username}"><xsl:value-of select="Case/KAM"/></a>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="Case/KAM"/>
          </xsl:otherwise>
        </xsl:choose>
      </td>
      <td><xsl:value-of select="Case/Coach"/></td>
      <td><xsl:value-of select="parent::Check/@Title"/> (#<xsl:apply-templates select="parent::Check/@No"/>)</td>
    </tr>
  </xsl:template>
  
  <xsl:template match="Acronym">
    <a target="_blank" href="{/Checks/@Base}projects/{../Id}"><xsl:value-of select="."/></a>
  </xsl:template>

  <xsl:template match="Acronym[../@CaseNo][not(../@ActivityNo)]">
    <a target="_blank" href="{/Checks/@Base}projects/{../Id}/cases/{../@CaseNo}"><xsl:value-of select="."/></a>
  </xsl:template>

  <xsl:template match="Acronym[../@ActivityNo]">
    <a target="_blank" href="{/Checks/@Base}projects/{../Id}/cases/{../@CaseNo}/activities/{../@ActivityNo}"><xsl:value-of select="."/></a>
  </xsl:template>

</xsl:stylesheet>
