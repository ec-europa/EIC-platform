<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

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
    <site:view>
      <site:window><title>Coach Match Login</title></site:window>
      <xsl:apply-templates select="*"/>
    </site:view>
  </xsl:template>

  <!-- Login dialog box -->
  <xsl:template match="Login[not(Redirected)]">
    <site:content>
      <div class="row login">
        <div>
          <xsl:apply-templates select="." mode="layout"/>
          <form class="form-horizontal" method="post" style="margin-bottom: 3em">
            <xsl:apply-templates select="To"/>
            <fieldset>
            <legend loc="login.title">Identification</legend>
              <xsl:apply-templates select="Hold"/>
              <xsl:apply-templates select="Check"/>
              <xsl:if test="not(Production) or Check">
                <div class="control-group">
                  <label class="control-label" for="login-user" loc="login.user">Login</label>
                  <div class="controls">
                    <input id="login-user" required="1" type="text" name="user" value="{User}"/>
                  </div>
                </div>
                <div class="control-group">
                  <label class="control-label" for="login-passwd" loc="login.pwd">Password</label>
                  <div class="controls">
                    <input id="login-passwd" required="1" type="password" name="password"/>
                  </div>
                </div>
                <div class="control-group" id="submit">
                  <div class="controls">
                    <input type="submit" class="btn">
                      <xsl:if test="Check">
                        <xsl:attribute name="value">Merge</xsl:attribute>
                      </xsl:if>
                    </input>
                  </div>
                </div>
              </xsl:if>
              <xsl:if test="not(Hold)">
                <div class="row" style="margin-top:2em;margin-left:0">
                  <xsl:apply-templates select="Register"/>
                  <xsl:apply-templates select="ECAS"/>
                  <xsl:if test="not(Production) or Check">
                    <div style="float:right"><a href="me/forgotten" title-loc="login.forgotten.hint" loc="login.forgotten">forgotten password</a></div>
                  </xsl:if>
                </div>
                <!-- <div class="control-group">
                  <xsl:variable name="url"><xsl:value-of select="Url"/></xsl:variable>
                  <span class="control-label" style="float:left"><a href="registration" title-loc="login.registration.hint" loc="login.registration">register</a></span>
                  <xsl:choose>
                    <xsl:when test="Url != ''">
                      <span class="control-label"><a href="login?url={$url}&amp;ecas=1">ECAS login</a></span>
                    </xsl:when>
                    <xsl:otherwise>
                      <span class="control-label"><a href="login?ecas=init">ECAS login</a></span>
                    </xsl:otherwise>
                  </xsl:choose>
                  <span class="control-label" style="float:right"><a href="me/forgotten" title-loc="login.forgotten.hint" loc="login.forgotten">forgotten password</a></span>
                </div> -->
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
    <p class="text-warning" style="font-size:133%;line-height: 1.5;text-align:justify">Your 'EU Login' account is not linked to the Coach Match.</p>
    <p class="text-warning" style="font-size:133%;line-height: 1.5;text-align:justify">If this is your <b>first visit</b> to the Coach Match platform and have no account: click on the <i>Create a new account</i> button.</p>
    <p class="text-warning" style="font-size:133%;line-height: 1.5;text-align:justify">If <b>you have a Coach Match account</b>, please enter your User name and Password to verify your identity and merge your 'EU Login' with your Coach Match account.</p>
    <p class="text-warning" style="font-size:133%;line-height: 1.5;text-align:left;margin-bottom:2em">If you face difficulties, please contact<br/> <a href="mailto:EASME-SME-COACHING@ec.europa.eu?subject=EU login Coach Match access" style="color:#c09853;">EASME-SME-COACHING@ec.europa.eu</a>.</p>
  </xsl:template>

  <xsl:template match="Register">
    <div class="span4">
      <a class="btn btn-primary" href="registration" title-loc="login.registration.hint" loc="login.registration">register</a>
    </div>
  </xsl:template>
  
  <!-- FIXME: Url ? -->
  <xsl:template match="ECAS">
    <xsl:variable name="url"><xsl:value-of select="../Url"/></xsl:variable>
    <div class="span2" style="margin-left:0">
      <xsl:choose>
        <xsl:when test="../Url != ''">
          <a class="btn btn-primary" href="login?url={$url}&amp;ecas=1">EU login</a>
        </xsl:when>
        <xsl:otherwise>
          <a class="btn btn-primary" href="login?ecas=init">EU login</a>
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
