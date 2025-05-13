defmodule GraphGenerator do
  @moduledoc """
  Модуль для генерации графов с настраиваемыми параметрами:
  - количество вершин
  - количество рёбер или коэффициент ветвления
  - ориентированный/неориентированный граф
  - взвешенный/невзвешенный граф

  Обеспечивает генерацию только связных графов и поддерживает
  визуализацию с сохранением в файл.
  """

  @doc """
  Генерирует граф с заданными параметрами.

  ## Параметры
  - vertices: количество вершин
  - edges_or_branching: количество рёбер или коэффициент ветвления (если < 1.0)
  - directed: true для ориентированного графа, false для неориентированного
  - weighted: true для взвешенного графа, false для невзвешенного
  - min_weight: минимальный вес ребра (для взвешенных графов)
  - max_weight: максимальный вес ребра (для взвешенных графов)

  ## Возвращает
  Кортеж {vertices, edges}, где:
  - vertices: список вершин [0, 1, 2, ...]
  - edges: список рёбер в формате {from, to} или {from, to, weight}
  """
  def generate(vertices, edges_or_branching, directed \\ false, weighted \\ false, min_weight \\ 1, max_weight \\ 10) do
    num_vertices = vertices

    # Определяем количество рёбер
    num_edges = if edges_or_branching < 1.0 do
      # Используем коэффициент ветвления
      trunc(edges_or_branching * num_vertices * (num_vertices - 1) / (if directed, do: 1, else: 2))
    else
      # Используем прямое указание количества рёбер
      trunc(edges_or_branching)
    end

    # Создаём список вершин
    vertices_list = Enum.to_list(0..(num_vertices - 1))

    # Сначала создаём остовное дерево для обеспечения связности
    edges = generate_spanning_tree(vertices_list, directed)

    # Добавляем оставшиеся рёбра до указанного количества
    remaining_edges = num_edges - length(edges)
    edges = if remaining_edges > 0 do
      add_random_edges(edges, vertices_list, remaining_edges, directed)
    else
      edges
    end

    # Добавляем веса, если требуется
    edges = if weighted do
      Enum.map(edges, fn {from, to} ->
        {from, to, :rand.uniform(max_weight - min_weight + 1) + min_weight - 1}
      end)
    else
      edges
    end

    {vertices_list, edges}
  end

  @doc """
  Генерирует остовное дерево, чтобы обеспечить связность графа.
  """
  defp generate_spanning_tree(vertices, directed) do
    # Начинаем с пустого набора рёбер
    [first | rest] = vertices
    visited = MapSet.new([first])
    unvisited = MapSet.new(rest)

    # Строим остовное дерево
    build_spanning_tree(visited, unvisited, [], directed)
  end

  defp build_spanning_tree(visited, unvisited, edges, directed) do
    if MapSet.size(unvisited) == 0 do
      edges
    else
      # Выбираем случайную посещённую вершину
      from = Enum.random(MapSet.to_list(visited))

      # Выбираем случайную непосещённую вершину
      to = Enum.random(MapSet.to_list(unvisited))

      # Добавляем ребро
      new_edges = if directed do
        [{from, to} | edges]
      else
        # Для неориентированного графа добавляем ребро в обоих направлениях
        # хотя для внутреннего представления достаточно одного
        [{from, to} | edges]
      end

      # Обновляем множества посещённых и непосещённых вершин
      new_visited = MapSet.put(visited, to)
      new_unvisited = MapSet.delete(unvisited, to)

      # Рекурсивно продолжаем построение
      build_spanning_tree(new_visited, new_unvisited, new_edges, directed)
    end
  end

  @doc """
  Добавляет случайные рёбра до достижения требуемого количества.
  """
  defp add_random_edges(edges, vertices, count, directed) do
    # Создаём множество существующих рёбер для быстрой проверки
    edge_set = MapSet.new(edges)

    add_edges_recursively(edges, edge_set, vertices, count, directed)
  end

  # Если количество ребер, которые нужно добавить, стало равным нулю
  defp add_edges_recursively(edges, edge_set, vertices, 0, _directed) do
    edges
  end

  defp add_edges_recursively(edges, edge_set, vertices, count, directed) do
    # Выбираем случайные вершины для нового ребра
    from = Enum.random(vertices)
    to = Enum.random(vertices)

    # Проверяем, что не создаём петлю и дубликаты
    if from != to &&
   !MapSet.member?(edge_set, {from, to}) &&
   (!directed && !MapSet.member?(edge_set, {to, from}) || directed) do
      new_edges = [{from, to} | edges]
      new_edge_set = MapSet.put(edge_set, {from, to})

      # Если граф неориентированный, добавляем обратное ребро в множество
      new_edge_set = if !directed do
        MapSet.put(new_edge_set, {to, from})
      else
        new_edge_set
      end

      add_edges_recursively(new_edges, new_edge_set, vertices, count - 1, directed)
    else
      # Если ребро некорректное, пробуем снова
      add_edges_recursively(edges, edge_set, vertices, count, directed)
    end
  end

  @doc """
  Создаёт матрицу смежности для графа.

  ## Параметры
  - vertices: список вершин
  - edges: список рёбер
  - weighted: true для взвешенного графа

  ## Возвращает
  Матрицу смежности в виде вложенных списков
  """
  def adjacency_matrix({vertices, edges}, weighted) do
    n = length(vertices)

    # Создаём пустую матрицу
    matrix = for _ <- 1..n, do: List.duplicate(0, n)

    # Заполняем матрицу
    Enum.reduce(edges, matrix, fn
      {from, to, weight}, acc when weighted ->
        update_in(acc, [Access.at(from), Access.at(to)], fn _ -> weight end)
      {from, to}, acc ->
        update_in(acc, [Access.at(from), Access.at(to)], fn _ -> 1 end)
    end)
  end

  @doc """
  Выводит матрицу смежности в консоль.
  """
  def print_adjacency_matrix(matrix) do
    n = length(matrix)

    # Печатаем заголовок
    IO.write("  ")
    Enum.each(0..(n-1), fn i -> IO.write(" #{i} ") end)
    IO.puts("")

    # Печатаем строки матрицы
    Enum.with_index(matrix, fn row, i ->
      IO.write("#{i} ")
      Enum.each(row, fn val -> IO.write(" #{val} ") end)
      IO.puts("")
    end)
  end

  @doc """
  Создаёт DOT-файл для визуализации графа с помощью Graphviz.

  ## Параметры
  - graph: кортеж {vertices, edges} с информацией о графе
  - filename: имя файла для сохранения (.dot будет добавлено автоматически)
  - directed: true для ориентированного графа
  - weighted: true для взвешенного графа
  """
  def generate_dot_file({vertices, edges}, filename, directed, weighted) do
    # Определяем тип графа для DOT
    graph_type = if directed, do: "digraph", else: "graph"
    edge_symbol = if directed, do: "->", else: "--"

    # Создаём содержимое DOT-файла
    dot_content = "#{graph_type} G {\n"

    # Добавляем вершины
    vertices_content = Enum.map(vertices, fn v -> "  #{v};" end)

    # Добавляем рёбра
    edges_content = Enum.map(edges, fn
      {from, to, weight} when weighted ->
        "  #{from} #{edge_symbol} #{to} [label=\"#{weight}\"];"
      {from, to} ->
        "  #{from} #{edge_symbol} #{to};"
    end)

    # Собираем итоговый файл
    dot_content = dot_content <> Enum.join(vertices_content ++ edges_content, "\n") <> "\n}"

    # Записываем файл
    File.write!("#{filename}.dot", dot_content)

    # Возвращаем путь к созданному файлу
    "#{filename}.dot"
  end

  @doc """
  Конвертирует DOT-файл в изображение с помощью Graphviz.

  ## Параметры
  - dot_file: путь к DOT-файлу
  - output_format: формат вывода (png, svg, pdf и т.д.)

  ## Возвращает
  Путь к созданному изображению

  ## Требования
  Для конвертации требуется установленный Graphviz с командой dot.
  """
  def convert_to_image(dot_file, output_format \\ "png") do
    # Формирование имени выходного файла с изображением
    output_file = String.replace(dot_file, ".dot", ".#{output_format}")
    # Формирование команды для запуска утилиты Graphviz с использованием команды dot
    command = "dot -T#{output_format} #{dot_file} -o #{output_file}"
    # Выполнение команды
    case System.cmd("dot", ["-T#{output_format}", dot_file, "-o", output_file]) do
      {_, 0} -> output_file
      _ -> raise "Failed to generate image. Make sure Graphviz is installed."
    end
  end
end

defmodule Main do
  @moduledoc """
  Основной модуль программы для взаимодействия с пользователем.
  """

  def run do
    IO.puts("Генератор графов")
    IO.puts("---------------")

    # Получаем параметры от пользователя
    vertices = get_integer_input("Введите количество вершин: ")

    IO.puts("\nВыберите способ задания количества рёбер:")
    IO.puts("1. Конкретное количество рёбер")
    IO.puts("2. Коэффициент ветвления (0.0 - 1.0)")
    edge_choice = get_integer_input("Ваш выбор (1 или 2): ")

    edges_or_branching = case edge_choice do
      1 ->
        get_integer_input("Введите количество рёбер: ")
      2 ->
        get_float_input("Введите коэффициент ветвления (0.0 - 1.0): ")
      _ ->
        IO.puts("Неверный выбор, используется количество рёбер.")
        get_integer_input("Введите количество рёбер: ")
    end

    directed = get_yes_no("Создать ориентированный граф? (y/n): ")
    weighted = get_yes_no("Создать взвешенный граф? (y/n): ")

    # Параметры весов
    {min_weight, max_weight} = if weighted do
      min_w = get_integer_input("Минимальный вес ребра: ")
      max_w = get_integer_input("Максимальный вес ребра: ")
      {min_w, max_w}
    else
      {1, 10}
    end

    # Генерируем граф
    graph = GraphGenerator.generate(vertices, edges_or_branching, directed, weighted, min_weight, max_weight)

    # Создаём и выводим матрицу смежности
    IO.puts("\nМатрица смежности:")
    matrix = GraphGenerator.adjacency_matrix(graph, weighted)
    GraphGenerator.print_adjacency_matrix(matrix)

    # Создаём визуализацию
    output_filename = get_string_input("\nВведите имя файла для сохранения графа (без расширения): ")
    dot_file = GraphGenerator.generate_dot_file(graph, output_filename, directed, weighted)

    # Спрашиваем, нужно ли конвертировать в изображение
    if get_yes_no("Сконвертировать DOT-файл в изображение? (y/n): ") do
      IO.puts("\nВыберите формат изображения:")
      IO.puts("1. PNG")
      IO.puts("2. SVG")
      IO.puts("3. PDF")
      format_choice = get_integer_input("Ваш выбор (1-3): ")

      format = case format_choice do
        1 -> "png"
        2 -> "svg"
        3 -> "pdf"
        _ -> "png"
      end

      image_file = GraphGenerator.convert_to_image(dot_file, format)
      IO.puts("Изображение сохранено в файл: #{image_file}")
    else
      IO.puts("DOT-файл сохранен в: #{dot_file}")
      IO.puts("Вы можете сконвертировать его в изображение с помощью Graphviz: dot -Tpng #{dot_file} -o #{output_filename}.png")
    end

    IO.puts("\nГотово!")
  end

  # Вспомогательные функции для получения ввода

  defp get_integer_input(prompt) do
    IO.write(prompt)
    input = IO.gets("") |> String.trim()

    case Integer.parse(input) do
      {value, _} when value > 0 -> value
      _ ->
        IO.puts("Пожалуйста, введите положительное целое число.")
        get_integer_input(prompt)
    end
  end

  defp get_float_input(prompt) do
    IO.write(prompt)
    input = IO.gets("") |> String.trim()

    case Float.parse(input) do
      {value, _} when value > 0 and value <= 1.0 -> value
      _ ->
        IO.puts("Пожалуйста, введите число в диапазоне от 0.0 до 1.0.")
        get_float_input(prompt)
    end
  end

  defp get_string_input(prompt) do
    IO.write(prompt)
    IO.gets("") |> String.trim()
  end

  defp get_yes_no(prompt) do
    IO.write(prompt)
    answer = IO.gets("") |> String.trim() |> String.downcase()

    case answer do
      "y" -> true
      "n" -> false
      _ ->
        IO.puts("Пожалуйста, введите 'y' или 'n'.")
        get_yes_no(prompt)
    end
  end
end

# Запускаем программу
Main.run()
