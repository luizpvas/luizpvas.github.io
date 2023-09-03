-- title: IO bound parsing
-- publication_date:
-- summary: Using threads to speed up `holistic-ruby`

I've working on a language server for the Ruby programming language for the past months. The current
implementation reads the source code, parses it and indexes the data sequentially in a single thread.

In Ruby MRI, 
