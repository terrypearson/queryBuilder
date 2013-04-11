PHP queryBuilder
============

This allows a user to quickly make basic SELECT, INSERT, UPDATE, and DELETE syntax for SQL queries in php.

_Why was this built?_
Well, I've used similar tools in Java and could not find much available in PHP. So, I made my own and open sourced it for you. 

I found the need for this when building queries conditionally. For example, my code may create a where clause like,
WHERE X=7, name='Don', id=99.
-Or-
Where X=7.

Because this largly depends on your PHP logic and the situation at the time, it makes it difficult to determine comma placement and stuff like that. So this class does it all for you.

Feel free to fork it and improve it. Then send me a pull request. I'd be glad to integrate it.

