from {{module}}.cli import main


def test_main_greets_by_name(capsys):
    assert main(["world"]) == 0
    assert capsys.readouterr().out == "hello, world\n"


def test_main_defaults_to_world(capsys):
    assert main([]) == 0
    assert capsys.readouterr().out == "hello, world\n"
