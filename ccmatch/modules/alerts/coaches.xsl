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
  <xsl:template match="/Batch">
    <site:view>
      <site:title><title><xsl:apply-templates select="." mode="title"/></title></site:title>
      <site:content>
        <h1>
          <xsl:apply-templates select="." mode="title"/>
        </h1>
        <h2>Summary</h2>
        <blockquote>
          <p>
            <xsl:value-of select="count(Inconsistent)"/> coaches have inconsistently answered to their profile<br/>
            on a total of <xsl:value-of select="@Total"/> coaches<br/>
            on a total of <xsl:value-of select="@Max"/> persons in database<br/>
            among which <xsl:value-of select="@Accepted"/> are accepted coaches<br/>
            among which <xsl:value-of select="@Activated"/> are accepted and activated coaches<br/>
            among which <xsl:value-of select="@Available"/> are accepted, activated and available coaches<br/>
            among which <xsl:value-of select="@NoSkills"/> are accepted, activated and available coaches but have no skills (<i>they will not appear in search results</i>)<br/>
            
          </p>
        </blockquote>
        <p>
          <xsl:apply-templates select="." mode="link"/>
        </p>

        <br/>

        <div id="sev-results-export"><a download="bad-coach-profiles.xls" href="#" class="btn btn-primary export">Generate Excel</a></div>
        <table id="inconsistents" name="todo-kam" class="table table-bordered todo">
          <caption>Coaches with inconsistent profiles (<xsl:value-of select="count(Inconsistent)"/>)
          <xsl:if test="@All = 'true'">
            <br/><span style="font-size:50%">Jump to <a href="#consistents">consitent coaches</a> table</span>
          </xsl:if>
          </caption>
          <xsl:call-template name="headers"/>
          <tbody localized="1">
            <xsl:apply-templates select="Inconsistent"/>
          </tbody>
        </table>
        
        <xsl:if test="@All = 'true'">
          <table id="consistents" name="todo-kam" class="table table-bordered todo">
            <caption>Coaches with consistent profiles (<xsl:value-of select="count(Consistent)"/>)<br/><span style="font-size:50%">Jump to <a href="#others">other persons</a> table</span></caption>
            <xsl:call-template name="headers"/>
            <tbody localized="1">
              <xsl:apply-templates select="Consistent"/>
            </tbody>
          </table>

          <table id="others" name="todo-kam" class="table table-bordered todo">
            <caption>All other persons (<xsl:value-of select="count(Person)"/>)<br/><span style="font-size:50%">Jump to <a href="#inconsistents">inconsistent coaches</a> table</span></caption>
            <xsl:call-template name="headers"/>
            <tbody localized="1">
              <xsl:apply-templates select="Person"/>
            </tbody>
          </table>
        </xsl:if>
      </site:content>
    </site:view>
  </xsl:template>
  
  
  <xsl:template match="/BatchAccr">
    <site:view>
      <site:title><title><xsl:apply-templates select="." mode="title"/></title></site:title>
      <site:content>
        <h1>
          <xsl:apply-templates select="." mode="title"/>
        </h1>
        <br/>
        <div id="results-export"><a download="coach-acceptances.xls" href="#" class="btn btn-primary export">Generate Excel</a><a download="coach-acceptances.csv" href="#" class="btn btn-primary export">Generate CSV</a></div>
        <table id="results-single" class="table table-bordered todo">
          <caption>Coaches with acceptances status (<xsl:value-of select="count(Coach)"/>)</caption>
          <xsl:call-template name="headers-accr"/>
          <tbody localized="1">
            <xsl:apply-templates select="Coach"/>
          </tbody>
        </table>
      </site:content>
    </site:view>
  </xsl:template>
  
  <xsl:template name="headers">
    <thead>
      <tr>
        <th>Last Name</th>
        <th>First Name</th>
        <th>Email</th>
        <th>Experiences with Established PME</th>
        <th>Expertise in Industrial Sectors<br/>(<i><xsl:value-of select="Thresholds/DomainActivities"/> max</i>)</th>
        <th>Expertise in Markets<br/>(<i><xsl:value-of select="Thresholds/TargetMarkets"/> max</i>)</th>
        <th>Expertise in Coaching Services<br/>(<i><xsl:value-of select="Thresholds/Services"/> max</i>)</th>
        <th>Summary</th>
        <th>Expertise in Business Innovation<br/>(<i><xsl:value-of select="Thresholds/CaseImpacts"/> max</i>)</th>
        <th>Acceptance Status</th>
        <th>Working Status</th>
      </tr>
    </thead>
  </xsl:template>
  
  <xsl:template name="headers-accr">
    <thead>
      <tr>
        <th>Last Name</th>
        <th>First Name</th>
        <th>Email</th>
        <th>Country Code</th>
        <th>Online CV</th>
        <th>Summary</th>
        <th>PDF CV?</th>
        <th>Acceptance Status</th>
        <th>Working Status</th>
        <th>Availabilities for coaching (Default value: <b>Yes</b>)</th>
        <th>Visibilities in Coach Search (Default value: <b>No</b>)</th>
        <th>Contact Ref.</th>
        <th>Expert Nb.</th>
        <th>Manager Comment</th>
        <th>Internal Login (deprecated)</th>
        <th>EU Login</th>
      </tr>
    </thead>
  </xsl:template>
  
  <xsl:template match="Batch" mode="title">List of coaches with profiles above threshold
  </xsl:template>
  
  <xsl:template match="BatchAccr" mode="title">List of coaches having applied for an acceptance
  </xsl:template>

  <xsl:template match="Batch[@All = 'true']" mode="title">List of all persons in database
  </xsl:template>
  
  <xsl:template match="Batch" mode="link">
    View <a href="alerts?all">all persons</a> in database
  </xsl:template>

  <xsl:template match="Batch[@All = 'true']" mode="link">
    View only <a href="alerts">inconsistent coaches</a> in database
  </xsl:template>
  
  <xsl:template match="Inconsistent|Consistent|Person">
    <tr>
      <td><a href="{Id}" target="_blank"><xsl:value-of select="Name/LastName"/></a></td>
      <td><xsl:value-of select="Name/FirstName"/></td>
      <td><xsl:value-of select="Email"/></td>
      <xsl:apply-templates select="Experiences"/>
      <xsl:apply-templates select="Competences"/>
      <xsl:apply-templates select="AS"/>
      <xsl:apply-templates select="WS"/>
    </tr>
  </xsl:template>
  
  <xsl:template match="Coach">
    <tr>
      <xsl:variable name="CV"><xsl:value-of select="normalize-space(CV-Link)"/></xsl:variable>
      <td><a href="{Id}" target="_blank"><xsl:value-of select="Name/LastName"/></a></td>
      <td><xsl:value-of select="Name/FirstName"/></td>
      <td><xsl:value-of select="Email"/></td>
      <td><xsl:value-of select="Country"/></td>
      <td><xsl:value-of select="$CV"/></td>
      <td><xsl:value-of select="Summary"/></td>
      <xsl:apply-templates select="HasPDFCV"/>
      <xsl:apply-templates select="AS"/>
      <xsl:apply-templates select="WS"/>
      <td><xsl:call-template name="Avail"/></td>
      <td><xsl:call-template name="Visib"/></td>
      <xsl:apply-templates select="CS"/>
      <xsl:apply-templates select="ExpertNumber"/>
      <xsl:apply-templates select="Comment"/>
      <xsl:apply-templates select="ILogin"/>
      <xsl:apply-templates select="EULogin"/>
    </tr>
  </xsl:template>
  
  <xsl:template name="Avail">
    <xsl:for-each select="Coaching">
      <xsl:value-of select="YesNoAvailRef/@_Display"/> (<xsl:value-of select="@For"/>)<xsl:text> </xsl:text>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="Visib">
    <xsl:for-each select="Visibility">
      <xsl:value-of select="YesNoAcceptRef/@_Display"/> (<xsl:value-of select="@For"/>)<xsl:text> </xsl:text>
    </xsl:for-each>
  </xsl:template>
  

  <xsl:template match="Experiences">
    <td>
      <xsl:choose>
        <xsl:when test="RenewalPlusConsolidationExpert/text() = '2'">yes</xsl:when>
        <xsl:otherwise>no</xsl:otherwise>
      </xsl:choose>
    </td>
    <td>
      <xsl:apply-templates select="DomainActivitiesCount/@Inc"/>
      <xsl:value-of select="DomainActivitiesCount"/>
    </td>
    <td>
      <xsl:apply-templates select="TargetsCount/@Inc"/>
      <xsl:value-of select="TargetsCount/text()"/>
    </td>
    <td>
      <xsl:apply-templates select="ServicesCount/@Inc"/>
      <xsl:value-of select="ServicesCount/text()"/>
    </td>
  </xsl:template>
  
  <xsl:template match="Competences">
    <td>
      <xsl:apply-templates select="Summary/@Inc"/>
      <xsl:choose>
        <xsl:when test="Summary != ''"><xsl:value-of select="substring(Summary/text(),0,25)"/>...</xsl:when>
        <xsl:otherwise>MISS</xsl:otherwise>
      </xsl:choose>
    </td>
    <td>
      <xsl:apply-templates select="CaseImpacts/@Inc"/>
      <xsl:value-of select="CaseImpacts/text()"/>
    </td>
  </xsl:template>
  
  <xsl:template match="HasPDFCV">
    <td>
      <xsl:choose>
        <xsl:when test="text() != ''">yes</xsl:when>
        <xsl:otherwise>MISS</xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>
  
  <xsl:template match="AS">
    <td>
      <xsl:value-of select="."/>
    </td>
  </xsl:template>
  
  <xsl:template match="WS">
    <td>
      <xsl:value-of select="."/>
    </td>
  </xsl:template>
  
  <xsl:template match="CS">
    <td>
      <xsl:value-of select="."/>
    </td>
  </xsl:template>
  
  <xsl:template match="ExpertNumber">
    <td>
      <xsl:value-of select="."/>
    </td>
  </xsl:template>
  <xsl:template match="Comment">
    <td>
      <xsl:for-each select="Text"><p><xsl:value-of select="."/></p></xsl:for-each>
    </td>
  </xsl:template>
  
  <xsl:template match="ILogin">
    <td>
      <xsl:choose>
        <xsl:when test="text() != ''"><xsl:value-of select="."/></xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="../EULogin != ''">N/A</xsl:when>
            <xsl:otherwise>Never logged in</xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>
  
  <xsl:template match="EULogin">
    <td>
      <xsl:choose>
        <xsl:when test="text() != ''">
          <xsl:value-of select="."/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="../ILogin != ''">Not merged yet</xsl:when>
            <xsl:otherwise>Never logged in</xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>
  
  <xsl:template match="@Inc[. = 'false']"/>

  <xsl:template match="@Inc[. = 'true']"><xsl:attribute name="style">color:red</xsl:attribute></xsl:template>
  
</xsl:stylesheet>
