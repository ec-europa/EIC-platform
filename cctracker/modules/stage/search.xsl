<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">
  
  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>
  
  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/search.xsl"/>
  
  <xsl:template match="/Search">
    <div id="results">
      <xsl:apply-templates select="NoRequest | Results/Projects"/>
    </div>
  </xsl:template>
  
  <xsl:template match="/Search[Confirm]" priority="1">
    <success status="202">
        <message loc="stage.request.empty">Voulez vous vraiment voir l'ensemble des cas et des activités ?</message>
    </success>
  </xsl:template>
  
  <xsl:template match="/Search[@Initial='true']" priority="1">
    <site:view skin="stage">
      <site:window><title loc="stage.search.title">Title</title></site:window>
      <site:title>
        <h1 loc="stage.search.title">Title</h1>
      </site:title>
      <site:content>
        <xsl:call-template name="formular"/>
        <div class="row">
          <div class="span12">
            <p id="c-busy" style="display: none; color: #999;margin-left:380px;height:32px">
              <span loc="term.loading" style="margin-left: 50px;vertical-align:middle">Recherche en cours...</span>
            </p>
            <div id="results">
              <xsl:apply-templates select="NoRequest | /Search/Results/Projects"/>
            </div>
          </div>
        </div>
        <xsl:call-template name="enterprise-modal"/>
        <xsl:call-template name="coach-modal"/>
        <xsl:call-template name="case-modal"/>
      </site:content>
    </site:view>
  </xsl:template>

  <!--xsl:template match="NoRequest">
  </xsl:template-->
 
  <!-- ======================= List of cases and activities ============================== -->
  <xsl:template match="Projects[not(Project)]">
    <h2 loc="app.title.noResults">Pas de résultats</h2>
    <p><i loc="stage.message.noCase">Il n'y a pas de résultats pour les critères sélectionnés.</i></p>
  </xsl:template>
  
  <xsl:template match="Projects[Project]">
    
    <!-- <h2 loc="term.cases">Cas et activités</h2> -->
    <h2>
      <span loc="stage.results.head">Résultats</span><xsl:text> - </xsl:text>
      <xsl:value-of select="count(Project)"/>
      <xsl:text> </xsl:text><span loc="stage.results.middle">projects incluant</span><xsl:text> </xsl:text>
      <xsl:value-of select="count(Project/Cases/Case)"/>
      <xsl:text> </xsl:text><span loc="stage.results.middle2">cas et</span><xsl:text> </xsl:text>
      <xsl:value-of select="count(Project/Cases/Case/Activities/Activity)"/>
      <xsl:text> </xsl:text><span loc="stage.results.tail">activité(s)</span>
    </h2>
    <table class="table table-bordered">
      <thead>
        <tr>
          <th loc="term.title" style="min-width:20%">Title</th>
          <th>Funding</th>
          <th>Grant agreement</th>
          <th loc="term.country">Pays</th>
          <th>KAM / Coach</th>
          <th loc="term.currentStatus">Statut</th>
        </tr>
      </thead>
      <tbody localized="1">
        <xsl:apply-templates select="Project">
          <!--<xsl:sort select="Enterprise/Name"/>-->
        </xsl:apply-templates>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Acronym"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Acronym[.='']"><i>no title</i>
  </xsl:template>

  <xsl:template match="Title" mode="tooltip">
    <xsl:attribute name="rel">tooltip</xsl:attribute>
    <xsl:attribute name="title"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Title[. = '']" mode="tooltip">
  </xsl:template> 

  <!-- =======================  Case KAM or Activity Coach  ============================== -->
  
  <xsl:template match="Coach">
    <a data-toggle="modal" href="persons/{Id}.modal" data-target="#coach-modal"><xsl:value-of select="FullName"/></a>
  </xsl:template>

  <xsl:template match="Coach[No]">
  </xsl:template>

  <xsl:template match="Coach[Soon]">pending
  </xsl:template>

  <xsl:template match="Coach[Miss]">MISSING
  </xsl:template>
  
  
  <!-- =======================  Project ============================== -->
  <xsl:template match="Project">
    <tr bgcolor="lightgreen">
      <td><xsl:apply-templates select="." mode="link"/></td>
      <td>
        <span style="display:block"><xsl:value-of select="Program"/></span>
        <span style="display:block"><xsl:value-of select="FundingRef"/></span>
        <span style="display:block"><xsl:value-of select="CallRef"/></span>
      </td>
      <td><xsl:value-of select="Grant"/></td>
      <td></td>
      <td></td>
      <td><xsl:value-of select="Status"/></td>
    </tr>
    <xsl:apply-templates select="Cases/Case"/>
  </xsl:template>
  
  <xsl:template match="Project" mode="link">
    <span><xsl:apply-templates select="Title" mode="tooltip"/><xsl:if test="not(Acronym)"><i>no acronym</i></xsl:if><xsl:apply-templates select="Acronym"/></span><i data-toggle="modal" href="projects/{Id}.modal" data-target="#case-modal" class="c-info">__</i>
  </xsl:template>
  
  <xsl:template match="Project[@Open or parent::Projects/@Open]" mode="link">
    <a href="projects/{Id}"><xsl:apply-templates select="Title" mode="tooltip"/><xsl:if test="not(Acronym)"><i>no acronym</i></xsl:if><xsl:apply-templates select="Acronym"/></a><i data-toggle="modal" href="projects/{Id}.modal" data-target="#case-modal" class="c-info">__</i>
  </xsl:template>
  
  <xsl:template match="Project[@Open or parent::Projects/@Open][count(Cases/Case) = 1]" mode="link" priority="1">
    <a href="projects/{Id}/cases/{Cases/Case/No}"><xsl:apply-templates select="Title" mode="tooltip"/><xsl:if test="not(Acronym)"><i>no acronym</i></xsl:if><xsl:apply-templates select="Acronym"/></a><i data-toggle="modal" href="projects/{Id}.modal" data-target="#case-modal" class="c-info">__</i>
  </xsl:template>
  
  <!-- =======================  Case ============================== -->
  <xsl:template match="Case">
    <tr style="background-color:rgb(255,193,77)">
      <td><xsl:apply-templates select="." mode="link"/><i class="c-info" data-toggle="modal" href="projects/{../../Id}/cases/{No}/enterprise" data-target="#enterprise-modal">__</i></td>
      <td></td>
      <td></td>
      <td><xsl:value-of select="Country"/></td>
      <td><xsl:apply-templates select="Coach"/></td>
      <td><xsl:value-of select="Status"/></td>
    </tr>
    <xsl:apply-templates select="Activities/Activity"/>
  </xsl:template>
  
  <xsl:template match="Case" mode="link">
    <xsl:choose>
      <xsl:when test="not(Enterprise/Name)">No enterprise selected</xsl:when>
      <xsl:otherwise><xsl:value-of select="Enterprise/Name"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="Case[@Open or ancestor::Projects/@Open or ancestor::Project/@Open]" mode="link">
    <a href="projects/{../../Id}/cases/{No}">
      <xsl:choose>
        <xsl:when test="not(Enterprise/Name)">No enterprise selected</xsl:when>
        <xsl:otherwise><xsl:value-of select="Enterprise/Name"/></xsl:otherwise>
      </xsl:choose>
    </a>
  </xsl:template>
  
  <xsl:template match="Case[@Open or ancestor::Projects/@Open or ancestor::Project/@Open][count(Activities/Activity) = 1]" mode="link" priority="1">
    <a href="projects/{../../Id}/cases/{No}/activities/{Activities/Activity/No}">
      <xsl:choose>
        <xsl:when test="not(Enterprise/Name)">No enterprise selected</xsl:when>
        <xsl:otherwise><xsl:value-of select="Enterprise/Name"/></xsl:otherwise>
      </xsl:choose>
    </a>
  </xsl:template>

  <!-- =======================  Activity ============================== -->
  <xsl:template match="Activity">
    <tr bgcolor="lightblue">
      <td><xsl:apply-templates select="." mode="link"/></td>
      <td></td>
      <td></td>
      <td></td>
      <td><xsl:apply-templates select="Coach"/></td>
      <td><xsl:value-of select="Status"/></td>
    </tr>
  </xsl:template>
  
  <xsl:template match="Activity" mode="link">
    <xsl:if test="not(Title)">no title</xsl:if><xsl:apply-templates select="Title"/>
  </xsl:template>

  <xsl:template match="Activity[ancestor::Cases/@Open or ancestor::Case/@Open or ancestor::Projects/@Open or ancestor::Project/@Open]" mode="link">
    <a href="projects/{../../../../Id}/cases/{../../No}/activities/{No}"><xsl:if test="not(Title)">no title</xsl:if><xsl:apply-templates select="Title"/></a>
  </xsl:template>

  <!-- ======================= Other or shared stuff ============================== -->
  
  <!-- Render a Coach to show in a modal -->
  <!-- DEPRECATED : see persons/modal.xsl instead -->
  <xsl:template match="Person">
    <!-- Modal -->
    <div id="coach-{Id}" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="label-{Id}" aria-hidden="true">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
        <h3 id="label-{Id}" loc="term.coach">Coach</h3>
      </div>
      <div class="modal-body">
        <p><xsl:apply-templates select="Name"/></p>
        <xsl:apply-templates select="Photo[.!='']"/>
        <p><span loc="term.enterprise">entreprise</span>: <xsl:value-of select="EnterpriseName"/></p>
        <p><a href="mailto:{Contacts/Email}"><xsl:value-of select="Contacts/Email"/></a></p>
        <p><span loc="term.mobile">Mobile</span>: <xsl:value-of select="Contacts/Mobile"/></p>
        <p><span loc="term.phoneAbbrev">Tel</span>: <xsl:value-of select="Contacts/Phone"/></p>
      </div>
      <div class="modal-footer">
        <button class="btn" data-dismiss="modal" aria-hidden="true" loc="action.close">Fermer</button>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="Name"><xsl:value-of select="FirstName/text()"/><xsl:text> </xsl:text><xsl:value-of select="LastName/text()"/>
  </xsl:template>

  <xsl:template match="Enterprise">
    <span>
      <xsl:choose>
        <xsl:when test="string-length(.) > 17">
          <xsl:attribute name="rel">tooltip</xsl:attribute>
          <xsl:attribute name="title"><xsl:value-of select="."/></xsl:attribute>
          <xsl:value-of select="normalize-space(substring(.,1,17))"/>...
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
      </xsl:choose>
    </span>
  </xsl:template>
  
  <xsl:template match="Service"><xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="Photo">
    <img src="persons/{.}" style="float:right"/>
  </xsl:template>

  <!-- Enterprise modal window (FIXME : factorize) -->
  <xsl:template name="enterprise-modal">
    <!-- Modal -->
    <div id="enterprise-modal" class="modal hide fade more-infos" tabindex="-1" role="dialog" aria-labelledby="label-enterprise" aria-hidden="true">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
        <h3 id="label-enterprise" loc="term.enterprise">Enterprise</h3>
      </div>
      <div class="modal-body">
      </div>
      <div class="modal-footer">
        <button class="btn" data-dismiss="modal" aria-hidden="true" loc="action.close">Fermer</button>
      </div>
    </div>
  </xsl:template>

  <!-- Coach modal window (FIXME : factorize) -->
  <xsl:template name="coach-modal">
    <!-- Modal -->
    <div id="coach-modal" class="modal hide fade more-infos" tabindex="-1" role="dialog" aria-labelledby="label-coach" aria-hidden="true">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
        <h3 id="label-coach">Community member</h3>
      </div>
      <div class="modal-body">
      </div>
      <div class="modal-footer">
        <button class="btn" data-dismiss="modal" aria-hidden="true" loc="action.close">Fermer</button>
      </div>
    </div>
  </xsl:template>

  <!-- Case modal window (FIXME : factorize) -->
  <xsl:template name="case-modal">
    <!-- Modal -->
    <div id="case-modal" class="modal hide fade more-infos" tabindex="-1" role="dialog" aria-labelledby="label-coach" aria-hidden="true"
         style="width:800px;margin-left:-400px;min-height:66%">
      <button type="button" class="close" data-dismiss="modal" aria-hidden="true" style="margin-right:10px;margin-top:10px">×</button>
      <div class="modal-body" style="max-height:100%">
      </div>
      <div class="modal-footer" style="height:30px">
        <button class="btn" data-dismiss="modal" aria-hidden="true" loc="action.close">Fermer</button>
      </div>
    </div>
  </xsl:template>
</xsl:stylesheet>
