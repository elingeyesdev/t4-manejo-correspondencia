@extends('errors.minimal')
@section('title', 'No se pudo completar la solicitud')
@section('code', $exception->getStatusCode())
@section('message', 'Comprueba la dirección o vuelve a la bandeja para continuar.')
