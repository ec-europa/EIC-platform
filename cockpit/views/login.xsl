<?xml version="1.0" encoding="UTF-8"?>
<!--
    Cockpit - EIC SME Dashboard Application

    Login form generation

    Author: Stéphane Sire <s.sire@free.fr>

    Turns a <Login> model to a <site:content> module containing a login dialog
    box. Does nothing if the model contains a <Redirected> element (e.g. as a
    consequence of a successful login when handling a POST - see login.xql).

     September 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <!-- integrated URL rewriting... -->
  <xsl:param name="xslt.base-url"></xsl:param>

  <xsl:template match="/">
    <site:view skin="fonts">
      <site:window><title>SME Dashboard Login</title></site:window>
      <site:layout>ecl-container</site:layout>
      <site:model>
        <Navigation xmlns="">
          <Mode>dashboard</Mode>
          <Name>SME Dashboard</Name>
        </Navigation>
      </site:model>
      <xsl:apply-templates select="*"/>
    </site:view>
  </xsl:template>

  <!-- Login dialog box -->
  <xsl:template match="Login[not(Redirected)]">
    <site:content>
      <div class="row login">
        <div>
          <xsl:apply-templates select="." mode="layout"/>
          <form class="ecl-form" method="post">
            <xsl:apply-templates select="To"/>
            <fieldset class="ecl-fieldset">
              <legend class="ecl-form-legend ecl-form-legend--level-1">
                <xsl:choose>
                  <xsl:when test="Check">Membership not approved</xsl:when>
                  <xsl:otherwise>Identification</xsl:otherwise>
                </xsl:choose>
              </legend>
              <xsl:apply-templates select="Hold"/>
              <xsl:apply-templates select="Check"/>
              <xsl:if test="not(Production) and not(Check)">
                <div class="ecl-form-group">
                  <label class="ecl-form-label" for="field-ID-1" loc="login.user">User name</label>
                  <div class="controls">
                    <input class="ecl-text-input" id="login-user" required="1" type="text" name="user" value="{User}"/>
                  </div>
                </div>
                <div class="ecl-form-group">
                  <label class="ecl-form-label" for="login-passwd" loc="login.pwd">Password</label>
                  <div class="controls">
                    <input id="login-passwd" class="ecl-text-input" required="1" type="password" name="password"/>
                  </div>
                </div>
                <div class="ecl-form-group" id="submit">
                  <div class="controls">
                    <input type="submit" class="ecl-button">
                      <xsl:if test="Check">
                        <xsl:attribute name="value">Merge</xsl:attribute>
                      </xsl:if>
                    </input>
                  </div>
                </div>
              </xsl:if>
              <xsl:if test="not(Hold) and not(Check)">
                <div class="row" style="margin-top:2em;margin-left:0">
                  <xsl:apply-templates select="ECAS"/>
                  <xsl:if test="not(Production)">
                    <button class="ecl-button ecl-button--secondary"><a href="me/forgotten" title-loc="login.forgotten.hint" loc="login.forgotten">forgotten password</a></button>
                  </xsl:if>
                </div>
              </xsl:if>
            </fieldset>
          </form>
        </div>
      </div>
    </site:content>
  </xsl:template>

 <xsl:template match="Login" mode="layout">
   <xsl:attribute name="class">span6 offset3</xsl:attribute>
 </xsl:template>

 <xsl:template match="Login[ECAS]" mode="layout">
   <xsl:attribute name="class">span7 offset3</xsl:attribute>
 </xsl:template>

  <xsl:template match="To">
    <xsl:variable name="action">{ concat($xslt.base-url, 'login?url=', .) }</xsl:variable>
  </xsl:template>

  <xsl:template match="To[. = '']">
    <xsl:variable name="action">{ concat($xslt.base-url, 'login') }</xsl:variable>
  </xsl:template>
  
  <xsl:template match="Login[Redirected]">
    <p>Goto <a href="{Redirected}"><xsl:value-of select="Redirected"/></a></p>
  </xsl:template>
  
  <xsl:template match="Login[SuccessfulMerge]">
    <p>Goto <a href="{SuccessfulMerge}"><xsl:value-of select="SuccessfulMerge"/></a></p>
  </xsl:template>
  
  <xsl:template match="Hold">
    <p class="text-warning" style="font-size:150%;line-height: 1.5;text-align:center" loc="login.hold">Please come back in a few minutes ...</p>
  </xsl:template>
  
  <xsl:template match="Check">
    <p style="font-color: 5b5db3; font-size:133%;line-height: 1.5;text-align:justify;margin-top:1em">It looks like you are not a member yet, please sign up.</p>
    <p style="font-color: 5b5db3; font-size:133%;line-height: 1.5;text-align:left;margin-bottom:2em">For further information, please contact us at<br/> <a href="mailto:EASME-SME-HELPDESK@ec.europa.eu?subject=EU login SME Dashboard access" style="color:#c09853;">EASME-SME-HELPDESK@ec.europa.eu</a>.</p>
    <a class="ecl-button ecl-button--call"><xsl:attribute name="href">admissions/entry</xsl:attribute>Sign up</a>
  </xsl:template>

  <xsl:template match="Register">
    <div class="span4">
      <a class="ecl-button ecl-button--primary" href="registration" title-loc="login.registration.hint" loc="login.registration">register</a>
    </div>
  </xsl:template>
  
  <!-- FIXME: Url ? -->
  <xsl:template match="ECAS">
    <xsl:variable name="url"><xsl:value-of select="../To"/></xsl:variable>
    <div class="span2" style="margin-left:0">
      <xsl:choose>
        <xsl:when test="../To != ''">
          <a class="ecl-button ecl-button--primary" href="login?url={$url}&amp;ecas=init">EU login</a>
        </xsl:when>
        <xsl:otherwise>
          <a class="ecl-button ecl-button--primary" href="login?ecas=init">EU login</a>
        </xsl:otherwise>
      </xsl:choose>
    </div>
  </xsl:template>
  
  <xsl:template match="ECAS[../Check]">
  </xsl:template>

  <!-- DEPRECATED -->
  <xsl:template match="CaseTracker">
    <div class="span4">
      <fieldset>
        <legend>Access to Case Tracker</legend>
        <p>Follow this <a href="{.}">link</a></p>
      </fieldset>
    </div>
  </xsl:template>

  <!-- DEPRECATED -->
  <xsl:template match="Unregistered">
    <div class="row login">
      <div class="span8">
        <fieldset>
          <legend>Unregistered user ?</legend>
          <p>Please drop an e-mail to <a href="mailto:EASME-SME-COACHING@ec.europa.eu?subject=Please register a coach">EASME-SME-COACHING@ec.europa.eu</a> to request access to one of these applications</p>
        </fieldset>
      </div>
    </div>
  </xsl:template>
</xsl:stylesheet>
