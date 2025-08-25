import 'package:crud_o_core/core/utility/toaster.dart';
import 'package:crud_o_core/resources/actions/crudo_action.dart';
import 'package:crud_o_core/resources/actions/crudo_action_result.dart';
import 'package:crud_o_core/resources/crudo_form_display_type.dart';
import 'package:crud_o_core/resources/resource_context.dart';
import 'package:crud_o_core/resources/resource_factory.dart';
import 'package:crud_o_core/resources/resource_operation_type.dart' show ResourceOperationType;
import 'package:crud_o_core/resources/resource_policy.dart';
import 'package:crud_o_core/resources/resource_repository.dart';
import 'package:crud_o_core/ui/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class CrudoResource<TModel extends dynamic> extends Object {
  final ResourceRepository<TModel> repository;
  final ResourcePolicy<TModel>? policy;

  CrudoResource({required this.repository, this.policy});

  /// **************************************************************************************************
  /// RESOURCE PAGES
  /// **************************************************************************************************

  /// Form to edit/create/view the resource
  Widget? formPage;

  /// Table to show the resource
  Widget? tablePage;


  /// **************************************************************************************************
  /// RESOURCE INFO
  /// **************************************************************************************************

  /// Override this method to define the id of the resource
  /// By default it returns the id of the model
  String getId(TModel model) {
    return model.id!.toString();
  }

  String singularName();

  String pluralName();

  IconData icon() => Icons.folder;

  String group() => '';

  int navigationSort() => 0;

  Map<String, dynamic> toMap(TModel model) => throw UnimplementedError();

  /// **************************************************************************************************
  /// ACTIONS
  /// **************************************************************************************************
  Future<CrudoAction?> createAction(
      {CrudoFormDisplayType displayType =
          CrudoFormDisplayType.fullPage}) async {
    if (formPage == null) return null;
    if (policy != null && !(await policy!.create())) return null;

    return CrudoAction(
        label: 'Crea',
        icon: Icons.add,
        action: (context, data) async {
          // Create destination target
          var target = RepositoryProvider(
            create: (context) => ResourceContext(
                id: "",
                data: data ?? {},
                originalOperationType: ResourceOperationType.create),
            child: formPage,
          );

          // Check if need to display as dialog or full page
          if (displayType == CrudoFormDisplayType.dialog) {
            return await showDialog(
              context: context,
              builder: (context) => target,
            );
          }

          // Display as full page
          return await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => target),
          );
        });
  }

  Future<CrudoAction?> editAction(TModel model, {CrudoFormDisplayType displayType = CrudoFormDisplayType.fullPage}) async {
    if (formPage == null) return null;
    if (policy != null && !(await policy!.update(model))) return null;
    return CrudoAction(
        label: 'Modifica',
        icon: Icons.edit,
        action: (context, data) async {

          var target = RepositoryProvider(
            create: (context) => ResourceContext(
                id: getId(model).toString(),
                data: data ?? {},
                model: model,
                originalOperationType: ResourceOperationType.edit),
            child: formPage,
          );

          // Check if need to display as dialog or full page
          if (displayType == CrudoFormDisplayType.dialog) {
            return await showDialog(
              context: context,
              builder: (context) => target,
            );
          }

          return await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => target),
          );
        });
  }

  Future<CrudoAction?> viewAction(TModel model, {CrudoFormDisplayType displayType = CrudoFormDisplayType.fullPage}) async {
    if (formPage == null) return null;
    if (policy != null && !(await policy!.view(model))) return null;
    return CrudoAction(
        label: 'Visualizza',
        icon: Icons.remove_red_eye,
        action: (context, data) async {

          var target = RepositoryProvider(
            create: (context) => ResourceContext(
                id: getId(model).toString(),
                data: data ?? {},
                model: model,
                originalOperationType: ResourceOperationType.view),
            child: formPage,
          );

          // Check if need to display as dialog or full page
          if (displayType == CrudoFormDisplayType.dialog) {
            return await showDialog(
              context: context,
              builder: (context) => target,
            );
          }

          return await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => target),
          );
        });
  }

  Future<CrudoAction?> listAction() async {
    if (tablePage == null) return null;
    if (policy != null && !(await policy!.viewAny())) return null;
    return CrudoAction(
        label: 'Lista',
        icon: Icons.list,
        action: (context, data) async {
          return await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => tablePage!),
          );
        });
  }

  Future<CrudoAction?> deleteAction(TModel model) async {
    if (policy != null && !(await policy!.delete(model))) return null;
    return CrudoAction(
        label: 'Elimina',
        icon: Icons.delete,
        color: Colors.red,
        action: (context, data) async {
          // Ask for confirmation
          var confirmed = await ConfirmationDialog.ask(
              context: context,
              title: 'Elimina ${singularName()}',
              message: 'Sei sicuro di voler procedere?');

          if (!confirmed) {
            return CrudoActionResult();
          }

          // Actually delete the resource
          try {
            await repository.delete(getId(model));
          } catch (e) {
            Toaster.error('Errore durante l\'eliminazione');
            return CrudoActionResult();
          }

          // // Get table state and reload
          // var tableState = context.read<CrudoTableBloc>().state;
          // if (tableState is TableLoadedState) {
          //   context
          //       .read<CrudoTableBloc>()
          //       .add(UpdateTableEvent(
          //
          //       tableState.request));
          // }
          return CrudoActionResult(refreshTable: true);
        });
  }

  /// All the actions owned by this resource that can be executed against a model
  Future<List<CrudoAction>> availableModelActions(TModel model) async {
    var actions = <CrudoAction>[];

    var editAction = await this.editAction(model);
    if (editAction != null) {
      actions.add(editAction);
    }

    var viewAction = await this.viewAction(model);
    if (viewAction != null) {
      actions.add(viewAction);
    }

    var deleteAction = await this.deleteAction(model);
    if (deleteAction != null) {
      actions.add(deleteAction);
    }

    return actions;
  }

  /// All the actions owned by this resource that can be executed against the resource
  Future<List<CrudoAction>> availableResourceActions() async {
    var actions = <CrudoAction>[];

    var createAction = await this.createAction();
    if (createAction != null) {
      actions.add(createAction);
    }

    var listAction = await this.listAction();
    if (listAction != null) {
      actions.add(listAction);
    }

    return actions;
  }

  /// **************************************************************************************************
  /// SHORTCUTS
  /// **************************************************************************************************
  ResourceFactory<TModel> get factory => repository.factory;

  TRepository getRepository<TRepository extends ResourceRepository<TModel>>() =>
      repository as TRepository;
}
