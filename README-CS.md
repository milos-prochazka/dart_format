#dart-format
Program pro formátování zdrojových souborů v DARTU. Program provádí předformátování pomocí Dartu. Je proto aby složka ve které je DART byla v PATH.

Přeformátovává standardní formát:
```dart
if (isTrue){
  call(something);
}
```

Na formát :
```dart
if (isTrue)
{
  call(something);
}
```

Parametrem je možné určit velikost odsazení (v krocích 2 mezery).

*Syntaxe:*
dart-format <source> [tab-size]

  * <source> - Vstupní soubor, nebo složka. Pokud je zadána složka, prohledá se, a u všech souborů s koncovkou .dart se provede formátování. Prohledávání složek se provádí rekurzivně a dart soubory se hledají i ve vnořených složkách.

  * [tab-size] - velikost odsazení.  Pokud je zadána 0 provede se pouze formátování DARTEM. Implicitně je 4.

*Zpracovávaní makra ve zdrojovém souboru*

  * //#set-tab size - Změna velikosti odsazení. Platí od příkazu do konce souboru, nebo k další změně. Možno zadat rozmezí 2 až 10.

  * //#pop-tab - Obnova velikosti odsazení nastaveného příkazem //#set-tab size

