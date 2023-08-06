-- title: Holistic Language Server - Event templates
-- publication_date: 2023-08-06
-- summary: Core communicates with extensions via event broadcasting, and each event has an implicit contract. Let's make them explicit.

### What problem am I trying to solve?

Core communicates with extensions via event broadcasting. Each event has an implicit contract for input and output.
Extensions need to know the contract in order to know what is available and what they should return.
Failing to adhere to the contract would result in a runtime exception.

Implicit contracts are difficult to understand and change.

### What can I do about it?

#### 1. Nothing

* Both emitters and listeners are defined in the same repository, so just dispatch events and assume the output is correct. Test would catch errors.
* No single place to look at to know which events are available and what are they made of.

#### 2. Make contracts explicit (!!)

* Define all events in a single place. Enumerate arguments and the expected output. When dispatching an event, verify the arguments and output match expected format. Throw runtime exception if not.
* Event templates serves the purpose of documentation, and they cannot get out of sync otherwise there would be runtime errors.

### How can I know I've chosen the best solution?

It should be a simple task to add new listeners and get the implementation right with confidence I'm not breaking other stuff.

_________________________

**Bonus:** Here's a snippet of the format to describe required params and expected output:

```ruby
TOPICS = {
  resolve_method_call_known_scope: {
    params: [:reference, :referenced_scope, :method_call_clue],
    output: ::Holistic::Ruby::Scope::Record
  }
}.freeze
```

[Here's the implementation.](https://github.com/luizpvas/holistic-ruby/blob/main/lib/holistic/extensions/events.rb#L4)