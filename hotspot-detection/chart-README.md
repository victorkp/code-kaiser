Making Charts Beautiful:

Antialias by generating chart at 4x size, then resizing down.

Give more three dimensional image by editing `/usr/local/share/perl5/GD/Graph/pie.pm`:
```
@@ -240,8 +240,13 @@
     for (my $i = 0; $i < @values; $i++)
     {
+       my @col = $self->pick_data_clr($i + 1);
+
         # Set the data colour
-        my $dc = $self->set_clr_uniq($self->pick_data_clr($i + 1));
+        my $dc = $self->set_clr_uniq(@col);
+
+       # Set the 3d shadow color (15% darker)
+       my $sc = $self->set_clr_uniq( map {$_ * 0.85} @col );

         # Set the angles of the pie slice
         # Angle 0 faces down, positive angles are clockwise

@@ -292,7 +297,7 @@

             {
                 $self->{graph}->fillToBorder(
                     $fill->[0], $fill->[1] + $self->{pie_height}/2,
-                    $ac, $dc);
+                    $ac, $sc);
             }
         }
     }

```
