EXCM 'analytics' module
====

The analytics module aims at recording end-users search requests (POST), results (at least first nb responses) and related user interaction events with the results presentation.

Requests must contain an internal UUID element(*) so that related events can be grouped.

(*) usually generated from XQuery function util:uuid()

Call to the API must also specify a user id because data is stored in a bucketized user file. It may also specify an optional host for applications where the request may come from multiple hosts identified with a number (web service or tunnel case). 

Settings :

    <Module>
      <Name>analytics</Name>
        <Property>
          <Key>level</Key>
          <Value>high</Value>
        </Property>
    </Module>

The analytics property control the amount of logging :

- high : record request, first 20 results and events
- mid : record request and events  
- off : no recording (same as no property defined at all)
