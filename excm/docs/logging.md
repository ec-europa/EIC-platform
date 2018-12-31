EXCM 'logging' API
====

The logging API is part of the misc.xqm module (misc:log-error and misc:log-error functions).

Settings :

    <Module>
      <Name>logging</Name>
      <Property>
        <Key>output</Key>
        <Value>log4j</Value>
      </Property>
    </Module>

The output property define the logging mechanism :

- log4j : using log4j 
- off : no logging (same as no property defined at all)

In order for the log4j output to work you need to configure an "excm.app" logger in your log4j configuration (*).

(*) see https://webgate.ec.europa.eu/CITnet/confluence/display/SMEIMKT/eXist-DB+tips+and+tricks

