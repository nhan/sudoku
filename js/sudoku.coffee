window.Sudoku = Sudoku = Ember.Application.create()
Sudoku.allValues = -> [1,2,3,4,5,6,7,8,9]

Sudoku.AllValuesMustAppearConstraint = Ember.Object.extend
  init: ->
    @get('cells').forEach (cell) =>
      cell.get('constraints').push this

  processMoreInformation: ->
    cells = @get 'cells'
    Sudoku.allValues().forEach (value) =>
      possibleCells = cells.filter (cell) ->
        cell.get('possibleValues').contains value
      if possibleCells.length is 1
        possibleCells.get('firstObject').setValue value, this

  processLessInformation: ->
    @get('cells').forEach (cell) =>
      cell.resetValue this

Sudoku.CannotHaveSameValueConstraint = Ember.Object.extend
  init: ->
    @get('constrainedCell').get('constraints').push this
    @get('relatedCells').forEach (cell) =>
      cell.get('constraints').push this

  processMoreInformation: ->
    knownValues = @get('relatedCells').mapProperty 'value'
    possibleValues = Sudoku.allValues().removeObjects knownValues
    constrainedCell = @get 'constrainedCell'
    constrainedCell.setPossibleValues possibleValues, this
    if possibleValues.length is 1
      value = possibleValues.get 'firstObject'
      constrainedCell.setValue value, this

  processLessInformation: ->
    constrainedCell = @get 'constrainedCell'
    constrainedCell.resetPossibleValues this
    constrainedCell.resetValue this

Sudoku.Cell = Ember.Object.extend
  constraints: Ember.computed -> []
  possibleValues: Ember.computed -> Sudoku.allValues()

  setValue: (value, informant) ->
    unless value is @get 'value'
      @set 'value', value
      @set 'valueInformant', informant
      @set 'possibleValues', [value]
      @set 'possibleValuesInformant', informant
      @notifyMoreInformation informant

  resetValue: (informant) ->
    if informant is @get('valueInformant') # and @get('value')
      @set 'value', undefined
      @set 'valueInformant', undefined
      @set 'possibleValues', Sudoku.allValues()
      @set 'possibleValuesInformant', undefined
      @notifyLessInformation informant

  setPossibleValues: (possibleValues, informant) ->
    if possibleValues.length <  @get('possibleValues').length
      @set 'possibleValues', possibleValues
      @set 'possibleValuesInformant', informant
      @notifyMoreInformation informant

  resetPossibleValues: (informant) ->
    if informant is @get('possibleValuesInformant') # and @get('possibleValues.length') < 9
      @set 'possibleValues', Sudoku.allValues()
      @set 'possibleValuesInformant', undefined
      @notifyLessInformation informant

  notifyMoreInformation: (informant) ->
    Ember.run =>
      @get('constraints').forEach (constraint) ->
        constraint.processMoreInformation() unless constraint is informant

  notifyLessInformation: (informant) ->
    Ember.run =>
      @get('constraints').forEach (constraint) ->
        constraint.processLessInformation() unless constraint is informant
    Ember.run.next =>
      @notifyMoreInformation informant

Sudoku.Board = Ember.Object.extend
  init: ->
    for x in [0...9]
      for y in [0...9]
        Sudoku.CannotHaveSameValueConstraint.create
          constrainedCell: @cellAt(x, y)
          relatedCells: @flatten(@blockAt x, y).addObjects(@rowAt(x, y))
            .addObjects(@columnAt(x, y)).without(@cellAt(x, y))

    @get('rows').forEach (row) ->
      Sudoku.AllValuesMustAppearConstraint.create
        cells: row

    @get('columns').forEach (column) ->
      Sudoku.AllValuesMustAppearConstraint.create
        cells: column

    @flatten(@get 'blocks').forEach (block) =>
      Sudoku.AllValuesMustAppearConstraint.create
        cells: @flatten(block)

  cells: Ember.computed ->
     for x in [0...9]
       for y in [0...9]
         Sudoku.Cell.create {x, y}

  cellAt: (x, y) ->
    @get('cells')[x][y]

  flatten: (block) ->
    block.reduce ((a, b) -> a.addObjects b), []

  blocks: Ember.computed ->
    for x in [0...9] by 3
      for y in [0...9] by 3
         @blockAt(x, y)

  blockAt: (x, y) ->
    for i in [0...3]
      for j in [0...3]
        @cellAt((x-(x%3))+i, (y-(y%3))+j)

  columns: Ember.computed -> @columnAt(0, y) for y in [0...9]

  columnAt: (x, y) -> @cellAt(row, y) for row in [0...9]

  rows: Ember.computed -> @rowAt(x, 0) for x in [0...9]

  rowAt: (x, y) -> @cellAt(x, column) for column in [0...9]

Sudoku.IndexRoute = Ember.Route.extend
  model: ->
    Sudoku.Board.create()

Sudoku.CellView = Ember.View.extend
  classNames: ['sudoku_cell']
  classNameBindings: ['valueType', 'classId']
  templateName: 'sudoku_cell'
  attributeBindings: ['tabindex']
  tabindex: 0

  possibleValues: Ember.computed ->
    @get('cell.possibleValues').join ' '
  .property 'cell.possibleValues'

  getId: (x, y) ->
    x = Math.min Math.max(x, 0), 8
    y = Math.min Math.max(y, 0), 8
    "cell_#{x}_#{y}"

  classId: Ember.computed ->
    @getId(@get('cell.x'), @get('cell.y'))

  valueType: Ember.computed ->
    if @get 'conflictingValue'
      'conflict'
    else if @get('cell.value') and @get('cell.valueInformant') isnt 'user'
      'computed'
  .property 'cell.value', 'cell.valueInformant', 'conflictingValue'

  value: Ember.computed ->
    conflictingValue = @get 'conflictingValue'
    if conflictingValue? then conflictingValue else @get 'cell.value'
  .property 'cell.value', 'conflictingValue'

  keyPress: (event) ->
    event.preventDefault()
    char = String.fromCharCode event.which

    if "123456789".indexOf(char) >= 0
      number = parseInt char
      if @get('cell.possibleValues').contains number
        @get('cell').setValue number, 'user'
        @set 'conflictingValue', undefined
      else
        @set 'conflictingValue', number

  keyDown: (event) ->
    if [8, 45, 37, 38, 39, 40].contains event.which
      event.preventDefault()
    switch event.which
      when 8, 45 # backspace, delete
        @get('cell').resetValue 'user'
        @set 'conflictingValue', undefined
      when 37 # left-arrow
        $(".#{@getId(@get('cell.x'), @get('cell.y') - 1)}").focus()
      when 38 # up-arrow
        $(".#{@getId(@get('cell.x') - 1, @get('cell.y'))}").focus()
      when 39 # right-arrow
        $(".#{@getId(@get('cell.x'), @get('cell.y') + 1)}").focus()
      when 40 # down-arrow
        $(".#{@getId(@get('cell.x') + 1, @get('cell.y'))}").focus()

  focusOut: (event) ->
    @set 'conflictingValue', undefined
