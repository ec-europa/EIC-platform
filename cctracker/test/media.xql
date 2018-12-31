import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../lib/media.xqm";

let $attachment := 
  <Attachment>
      <Title>Coaching plan proposal</Title>
      <List>
          <Item>5H: Promotion</Item>
          <Item>3H: Vente</Item>
          <Item>2H: Test</Item>
      </List>
      <Text>Total number of hours : 10H</Text>
  </Attachment>

return media:message-to-plain-text($attachment)