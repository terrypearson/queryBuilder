<?php

class QueryBuilder{
	
	/*
	 * This class creates the query, but does not execute. Insert this query into any normal process you might have in order to achieve
	 * the end result.
	 * 
	 * Usage Examples:
	 * 	SELECT
	 * 		$queryString = QueryBuilder::select()->fields("name","age")->table("users")->where("userID==7","name=='george'")->getQuery();
	 * 		$queryString = QueryBuilder::select()->fields("name")->fields("age")->table("users")->where("userID==7","name=="george")->getQuery();
	 * 	INSERT
	 * 		$queryString = QueryBuilder::insert()->fields("name","age")->values("Terry",31)->getQuery();
	 * 		$queryString = QueryBuilder::insert()->fields("name")->values("Terry")->fields("age")->values(31)->getQuery();
	 * 	UPDATE
	 * 		$queryString = QueryBuilder::update()->fields("name","age")->values("Terry",31)->where(userId=7)->getQuery();
	 * 		$queryString = QueryBuilder::update()->fields("name")->values("Terry")->fields("age")->values(31)->where(userId=7,"name=='terry'")->getQuery();
	 * 	DELETE
	 * 		$queryString = QueryBuilder::delete()->where("userId==7",name=="'terry'")->getQuery();
	 */
	
	
	private $queryType;
	private $queryString;
	private $table = array();
	
	private $selectFields = array();
	private $insertFields = array();
	private $updateFields = array();
	
	private $insertValues = array();
	private $updateValues = array();
	private $whereClauses = array();
	
	private $errors = array();
	
	function getQuery(Array &$errors=array()){
		$originalErrorCount = count($errors);
		switch ($this->queryType){
			case "SELECT":
				$result = $this->validateSelect($this->errors);
				break;
			case "UPDATE":
				$result = $this->validateUpdate($this->errors);
				break;
			case "INSERT":
				$result = $this->validateInsert($this->errors);
				break;
			case "DELETE":
				$result = $this->validateDelete($this->errors);
				break;
			default:
				$this->errors[] = "Invalid query type or query type not specified:".$this->queryType;
		}
		
		$errors = array_merge($this->errors,$errors);
		
		$newErrorCount = count($errors);
		if($newErrorCount>$originalErrorCount){
			return null;
		}
		return $result;
		
	}
	
	private function validateSelect(Array &$errors=array()){
		$selectString = "*"; //Default
		if(!empty($this->selectFields)){
			$selectString = implode(",", $this->selectFields);
		}
		
		if(empty($this->table)){
			$this->errors[] = "The select statement cannot be validated because it is missing the table name.";
			return null;
		}
		$tableString = implode(",", $this->table);
		
		//TODO, make it a two dimensional array so that we can do AND and OR clauses
		//i.e.
		// WHERE [0][userid=7]    [0][name='terry']		[1][userid=0]
		//Would be interpreted WHERE (userid==7 AND name=='terry') OR (userid==0)
		
		$whereString = "true"; //default
		if(!empty($this->whereClauses)){
			$whereString = $this->createWhereClause();
		}
		
		$this->queryString = "SELECT " . $selectString . " FROM " .  $tableString . " WHERE " . $whereString;
		
		return $this->queryString;
		
	}
	
	private function validateUpdate(Array &$errors=array()){
		
		if(empty($this->updateFields)){
			$this->errors[] = "The update statement is in error because no fields are set to update.";
			return null;
		}
		
		if(empty($this->updateValues)){
			$this->errors[] = "The update statement is in error because no values are set to update.";
			return null;
		}
		
		if(count($this->updateFields) != count($this->updateValues)){
			$this->errors[] = "The update statement is in error because the number of fields did not match the number of values.";
			
			return null;
		}
		
		$updateArray = array();
		
		//Creating equals statement for fields
		for($i=0;$i<count($this->updateFields);$i++){
			$quote = "'";
			if(is_numeric($this->updateValues[$i])){
				$quote = "";
			}
			
			$updateArray[] = $this->updateFields[$i] . "=" . $quote.$this->updateValues[$i].$quote;
			
		}
		$updateString = implode(",",$updateArray);
		
		if(empty($this->table)){
			$this->errors[] = "The update statement cannot be validated because it is missing the table name.";
			
			return null;
		}
		$tableString = implode(",", $this->table);
		
		$whereString = "true"; //default
		if(!empty($this->whereClauses)){
			$whereString = $this->createWhereClause();
		}
		
		$this->queryString = "UPDATE " . $tableString ." SET " . $updateString . " WHERE " . $whereString;
		return $this->queryString;
	}
	
	private function validateInsert(Array &$errors=array()){
		
		//TODO Code this
		if(empty($this->insertFields)){
			$this->errors[] = "The insert statement is in error because no fields are set to insert.";
			
			return null;
		}
		
		if(empty($this->insertValues)){
			$this->errors[] = "The insert statement is in error because no values are set to insert.";
			
			return null;
		}
		
		if(count($this->insertFields) != count($this->insertValues)){
			$this->errors[] = "The insert statement is in error because the number of fields did not match the number of values.";
			
			return null;
		}
		
		//For inserts, only one table is allowed. Not zero, and certainly not two or more! We only check that one exists.
		if(empty($this->table)){
			$this->errors[] = "The insert statement cannot be validated because it is missing the table name.";
			
			return null;
		}
		
		$insertFieldsString = implode(",",$this->insertFields);
		
		$insertValuesString = "";
		for($i=0;$i<count($this->insertValues);$i++){
			$quote = "'";
			if(is_numeric($this->insertValues[$i])){
				$quote = "";
			}
				
			$this->insertValues[$i] = $quote.$this->insertValues[$i].$quote;
				
		}

		$insertValuesString = implode(",",$this->insertValues);
		$tableString = implode(",", $this->table);
		
		$this->queryString = "INSERT INTO " . $tableString ." (" . $insertFieldsString . ")" ." VALUES " . "(" .$insertValuesString . ")";
		
		return $this->queryString;
		
	}
	
	
	private function validateDelete(Array &$errors=array()){
		if(empty($this->whereClauses)){
			$this->errors[] = "The delete statement is in error because no fields are set to delete. This is a safeguard. If you want to delete all, try to use 'TRUE' in the where clause";
			
			return null;
		}
		$whereString = $this->createWhereClause();
		
		//Just a hint, dont add more than one table to the array, it just makes a mess.
		if(empty($this->table)){
			$this->errors[] = "The delete statement cannot be validated because it is missing the table name.";
			return null;
		}
		$tableString = implode(",", $this->table);
		
		$this->queryString = "DELETE FROM " . $tableString ." WHERE " . $whereString;
		return $this->queryString;
	}
	
	private function createWhereClause(){
		
		
		
		if(empty($this->whereClauses)){
			return null;
		}
		
		$andGroupsArray = null;
		
		foreach($this->whereClauses as $whereGroup){
			$whereString = "";
			$whereString = "(".implode(" AND ",$whereGroup) .")";
			$andGroupsArray[] = $whereString;
		}
		
		$whereStringComplete = implode(" OR ",$andGroupsArray);
		return $whereStringComplete;
	}
	
	/**
	 * Updates the appropriate fields string based on the query type that was initialized.
	 * @param String $vars - one parameter for each field.
	 * @return $this
	 */
	function fields($vars){
		if(empty($vars)){
			return $this;
		}
		
		$arg_list = func_get_args();
		
		switch ($this->queryType){
			case "SELECT":
				$this->selectFields = array_merge($this->selectFields,$arg_list);
				break;
			case "UPDATE":
				$this->updateFields = array_merge($this->updateFields,$arg_list);
				break;
			case "INSERT":
				$this->insertFields = array_merge($this->insertFields,$arg_list);
				break;
			default:
				$this->errors[] = "Invalid query type for fields function:".$this->queryType;
		}

		return $this;
	}
	
	/**
	 * Updates the appropriate values corresponding to the fields initialized.
	 * @param String $vars - one parameter for each value.
	 * @return $this
	 */
	function values($vars){
		if(empty($vars)){
			return $this;
		}
	
		$arg_list = func_get_args();
	
		switch ($this->queryType){
			case "UPDATE":
				$this->updateValues = array_merge($this->updateValues,$arg_list);
				break;
			case "INSERT":
				$this->insertValues = array_merge($this->insertValues,$arg_list);
				break;
			default:
				$this->errors[] = "Invalid query type for values function:".$this->queryType;
		}
	
		return $this;
	}
	
	/**
	 * Each call to the function will "and" together the conditions, but each separate function call will be "or"ed.
	 * i.e. ->where("x==5","z==2")->where("a>6") would become:
	 * 						WHERE (x==5 AND z==2) OR (a>6)
	 * @param String $vars - one parameter for each where clause.
	 * @return $this
	 */
	function where($vars){

		$arg_list = func_get_args();
		
		if(empty($arg_list)){
			return $this;
		}
		
		//What is happening here is that each function call puts the new where clauses inside the whereClauses array.
		//So each time the function is called, it generates a new row that contains an array
		$this->whereClauses[] = $arg_list;
		
		return $this;
	}
	
	function table($table){
		if(empty($table)){
			return $this;
		}
		
		$arg_list = func_get_args();
		
		$this->table = array_merge($this->table,$arg_list);
		return $this;
	}
	
	/**
	 * Returns a new query builder with select query type.
	 */
	static function select(){
		$theObject = new self();
		$theObject->queryType = 'SELECT';
		return $theObject;
	}
	
	/**
	 * Returns a new query builder with update query type.
	 */
	static function update(){
		$theObject = new self();
		$theObject->queryType = 'UPDATE';
		return $theObject;
	}
	
	/**
	 * Returns a new query builder with insert query type.
	 */
	static function insert(){
		$theObject = new self();
		$theObject->queryType = 'INSERT';
		return $theObject;
	}
	
	/**
	 * Returns a new query builder with delete query type.
	 */
	static function delete(){
		$theObject = new self();
		$theObject->queryType = 'DELETE';
		return $theObject;
	}
	
	
}

?>
